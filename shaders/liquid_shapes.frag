#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uSpeed;
uniform float uIntensity;
uniform vec4 uShapeColor0;
uniform vec4 uShapeColor1;
uniform vec4 uShapeColor2;
uniform vec2 uShapePos0;
uniform vec2 uShapePos1;
uniform vec2 uShapePos2;
uniform vec2 uShapePos3;
uniform vec2 uShapePos4;
uniform float uShapeSize;

out vec4 fragColor;

float sdCircle(vec2 p, vec2 center, float r) {
  return length(p - center) - r;
}

float sdRoundBox(vec2 p, vec2 center, vec2 halfSize, float r) {
  vec2 q = abs(p - center) - halfSize + r;
  return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

float sdEquilateralTriangle(vec2 p, vec2 center, float r) {
  vec2 q = p - center;
  const float k = 1.7320508; // sqrt(3.0)
  q.x = abs(q.x) - r;
  q.y = q.y + r / k;
  if (q.x + k * q.y > 0.0) {
    q = vec2(q.x - k * q.y, -k * q.x - q.y) / 2.0;
  }
  q.x -= clamp(q.x, -2.0 * r, 0.0);
  return -length(q) * sign(q.y);
}

float opSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

vec4 colorForIndex(int index) {
  // Kind cycle: [triangle, roundedSquare, circle, triangle, roundedSquare]
  if (index == 0 || index == 3) return uShapeColor0;
  if (index == 1 || index == 4) return uShapeColor1;
  return uShapeColor2;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 aspectUv = vec2(uv.x * aspect, uv.y);

  vec2 p0 = vec2(uShapePos0.x * aspect, uShapePos0.y);
  vec2 p1 = vec2(uShapePos1.x * aspect, uShapePos1.y);
  vec2 p2 = vec2(uShapePos2.x * aspect, uShapePos2.y);
  vec2 p3 = vec2(uShapePos3.x * aspect, uShapePos3.y);
  vec2 p4 = vec2(uShapePos4.x * aspect, uShapePos4.y);

  float size = uShapeSize * clamp(uIntensity, 0.3, 2.0);
  float blend = 0.02 + 0.012 * clamp(uIntensity, 0.0, 2.0);

  float d0 = sdEquilateralTriangle(aspectUv, p0, size);
  float d1 = sdRoundBox(aspectUv, p1, vec2(size), size * 0.3);
  float d2 = sdCircle(aspectUv, p2, size);
  float d3 = sdEquilateralTriangle(aspectUv, p3, size);
  float d4 = sdRoundBox(aspectUv, p4, vec2(size), size * 0.3);

  float merged = opSmoothUnion(d0, d1, blend);
  merged = opSmoothUnion(merged, d2, blend);
  merged = opSmoothUnion(merged, d3, blend);
  merged = opSmoothUnion(merged, d4, blend);

  // Color by whichever shape's raw (un-blended) surface is nearest.
  float nearest = d0;
  vec4 color = colorForIndex(0);
  if (d1 < nearest) { nearest = d1; color = colorForIndex(1); }
  if (d2 < nearest) { nearest = d2; color = colorForIndex(2); }
  if (d3 < nearest) { nearest = d3; color = colorForIndex(3); }
  if (d4 < nearest) { nearest = d4; color = colorForIndex(4); }

  // Narrower outer falloff than `blend * 2.0` (see liquid_orbs.frag for
  // the same fix, applied there after live-device testing showed the
  // wider falloff washing shapes into near-full-screen coverage).
  float glowWidth = 0.016 + 0.006 * clamp(uIntensity, 0.0, 2.0);
  float shimmer = 0.95 + 0.05 * sin(uTime * uSpeed * 1.5);
  float alpha = clamp(
    (1.0 - smoothstep(-blend, glowWidth, merged)) * 0.85 * shimmer,
    0.0, 1.0);

  vec4 background = vec4(1.0, 1.0, 1.0, 1.0);
  fragColor = mix(background, vec4(color.rgb, 1.0), alpha);
}
