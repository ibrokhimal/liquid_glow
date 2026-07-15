#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uSpeed;
uniform float uIntensity;
uniform vec4 uBackgroundColor;
uniform vec4 uOrbColor0;
uniform vec4 uOrbColor1;
uniform vec2 uOrbPos0;
uniform vec2 uOrbPos1;
uniform vec2 uOrbPos2;
uniform float uOrbRadius;

out vec4 fragColor;

float sdCircle(vec2 p, vec2 center, float r) {
  return length(p - center) - r;
}

float opSmoothUnion(float d1, float d2, float k) {
  float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
  return mix(d2, d1, h) - k * h * (1.0 - h);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float aspect = uSize.x / uSize.y;
  vec2 aspectUv = vec2(uv.x * aspect, uv.y);

  vec2 pos0 = vec2(uOrbPos0.x * aspect, uOrbPos0.y);
  vec2 pos1 = vec2(uOrbPos1.x * aspect, uOrbPos1.y);
  vec2 pos2 = vec2(uOrbPos2.x * aspect, uOrbPos2.y);

  float radius = uOrbRadius * clamp(uIntensity, 0.3, 2.0);
  float blend = 0.06 + 0.04 * clamp(uIntensity, 0.0, 2.0);

  float d0 = sdCircle(aspectUv, pos0, radius);
  float d1 = sdCircle(aspectUv, pos1, radius);
  float d2 = sdCircle(aspectUv, pos2, radius);

  float merged = opSmoothUnion(d0, d1, blend);
  merged = opSmoothUnion(merged, d2, blend);

  // Color by whichever orb's raw (un-blended) surface is nearest.
  vec4 orbColor = uOrbColor0;
  float nearest = d0;
  if (d1 < nearest) {
    nearest = d1;
    orbColor = uOrbColor1;
  }
  if (d2 < nearest) {
    nearest = d2;
    orbColor = uOrbColor0;
  }

  float shimmer = 0.9 + 0.1 * sin(uTime * uSpeed * 2.0);
  float glow = clamp(
    (1.0 - smoothstep(-blend, blend * 3.0, merged)) * shimmer, 0.0, 1.0);

  fragColor = mix(uBackgroundColor, orbColor, glow);
}
