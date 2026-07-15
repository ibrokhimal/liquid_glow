#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uSpeed;
uniform float uIntensity;
uniform vec2 uOrigin;
uniform vec4 uTouch; // xy = normalized position, z = strength, w = age (s)
uniform float uColorCount;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform vec4 uColor4;
uniform vec4 uColor5;
uniform float uNoiseScale;

out vec4 fragColor;

// 2D simplex noise (Ashima Arts / Stefan Gustavson, public domain).
vec3 permute(vec3 x) {
  return mod(((x * 34.0) + 1.0) * x, 289.0);
}

float simplexNoise(vec2 v) {
  const vec4 C = vec4(0.211324865405187, 0.366025403784439,
                       -0.577350269189626, 0.024390243902439);
  vec2 i  = floor(v + dot(v, C.yy));
  vec2 x0 = v - i + dot(i, C.xx);
  vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
  vec4 x12 = x0.xyxy + C.xxzz;
  x12.xy -= i1;
  i = mod(i, 289.0);
  vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0))
                  + i.x + vec3(0.0, i1.x, 1.0));
  vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy),
                           dot(x12.zw, x12.zw)), 0.0);
  m = m * m;
  m = m * m;
  vec3 x = 2.0 * fract(p * C.www) - 1.0;
  vec3 h = abs(x) - 0.5;
  vec3 ox = floor(x + 0.5);
  vec3 a0 = x - ox;
  m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
  vec3 g;
  g.x  = a0.x  * x0.x  + h.x  * x0.y;
  g.yz = a0.yz * x12.xz + h.yz * x12.yw;
  return 130.0 * dot(m, g);
}

float fbm(vec2 p) {
  float value = 0.0;
  float amplitude = 0.5;
  for (int i = 0; i < 4; i++) {
    value += amplitude * simplexNoise(p);
    p *= 2.0;
    amplitude *= 0.5;
  }
  return value;
}

vec4 colorAt(int index) {
  if (index <= 0) return uColor0;
  if (index == 1) return uColor1;
  if (index == 2) return uColor2;
  if (index == 3) return uColor3;
  if (index == 4) return uColor4;
  return uColor5;
}

vec4 rampColor(float t) {
  float count = clamp(uColorCount, 2.0, 6.0);
  float scaled = clamp(t, 0.0, 1.0) * (count - 1.0);
  int lower = int(floor(scaled));
  int upper = int(min(float(lower) + 1.0, count - 1.0));
  float frac = scaled - float(lower);
  return mix(colorAt(lower), colorAt(upper), frac);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec2 aspectUv = uv;
  aspectUv.x *= uSize.x / uSize.y;

  float t = uTime * uSpeed * 0.15;

  // Domain warp: a lower-frequency noise field offsets the sampling
  // coordinate before the higher-frequency detail field is sampled.
  vec2 warp = vec2(
    fbm(aspectUv * 1.5 * uNoiseScale + vec2(0.0, t)),
    fbm(aspectUv * 1.5 * uNoiseScale + vec2(5.2, -t))
  );
  vec2 warped = aspectUv + warp * 0.5 * uIntensity;

  float n = fbm(warped * 2.0 * uNoiseScale + t);
  n = n * 0.5 + 0.5;

  // Touch reaction: a localized bump that decays with uTouch.w (age).
  float touchDecay = clamp(1.0 - uTouch.w / 1.5, 0.0, 1.0);
  vec2 touchUv = vec2(uTouch.x * uSize.x / uSize.y, uTouch.y);
  float touchDist = distance(aspectUv, touchUv);
  float touchBump = uTouch.z * touchDecay * exp(-touchDist * 6.0);
  n += touchBump;

  // Bias the sample toward uOrigin so the animation appears to radiate
  // from the configured origin/alignment point.
  float originDist = distance(uv, uOrigin);
  n = mix(n, n * (1.0 - originDist), 0.3);

  fragColor = rampColor(n);
}
