#version 460 core

precision mediump float;

#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;
uniform float uBorderWidth;
uniform float uBlurRadius;
uniform vec4 uCornerRadius; // topLeft, topRight, bottomRight, bottomLeft
uniform vec4 uEdgeMask;     // top, right, bottom, left (1.0 = visible)
uniform float uSpeed;
uniform float uPulse;
uniform float uWave;
uniform float uColorCycle;
uniform float uColorCount;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;

out vec4 fragColor;

float sdRoundRect(vec2 p, vec2 halfSize, vec4 r) {
  r.xy = (p.x > 0.0) ? r.yz : r.xw;
  r.x  = (p.y > 0.0) ? r.y  : r.x;
  vec2 q = abs(p) - halfSize + r.x;
  return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

vec4 colorAt(int index) {
  if (index <= 0) return uColor0;
  if (index == 1) return uColor1;
  if (index == 2) return uColor2;
  return uColor3;
}

vec4 rampColor(float t) {
  int count = int(clamp(uColorCount, 2.0, 4.0));
  float scaled = fract(clamp(t, 0.0, 1.0)) * float(count);
  int lower = int(floor(scaled));
  lower = lower >= count ? lower - count : lower;
  int upper = lower + 1;
  upper = upper >= count ? upper - count : upper;
  float frac = fract(scaled);
  return mix(colorAt(lower), colorAt(upper), frac);
}

void edgeAlpha(vec2 p, vec2 halfSize, out float top, out float right,
               out float bottom, out float left) {
  float edgeSpan = 0.35;
  top    = smoothstep(halfSize.y * (1.0 - edgeSpan), halfSize.y, -p.y);
  bottom = smoothstep(halfSize.y * (1.0 - edgeSpan), halfSize.y,  p.y);
  right  = smoothstep(halfSize.x * (1.0 - edgeSpan), halfSize.x,  p.x);
  left   = smoothstep(halfSize.x * (1.0 - edgeSpan), halfSize.x, -p.x);
}

void main() {
  vec2 fragCoord = FlutterFragCoord().xy;
  vec2 halfSize = uSize * 0.5;
  vec2 p = fragCoord - halfSize;

  float dist = sdRoundRect(p, halfSize, uCornerRadius);

  // Glow falls off outward from the border line (dist == 0 is the edge).
  float band = abs(dist);
  float glow = 1.0 - smoothstep(0.0, uBorderWidth + uBlurRadius, band);

  float pulse = 1.0 + uPulse * 0.35 * sin(uTime * uSpeed * 3.0);
  glow *= pulse;

  float top, right, bottom, left;
  edgeAlpha(p, halfSize, top, right, bottom, left);
  float maskAlpha =
      top    * uEdgeMask.x +
      right  * uEdgeMask.y +
      bottom * uEdgeMask.z +
      left   * uEdgeMask.w;
  maskAlpha = clamp(maskAlpha, 0.0, 1.0);

  // atan(p.y, p.x) has its branch cut on the negative x-axis (left-middle of
  // the rect), jumping from +pi to -pi there. sin(k * angle) only matches up
  // across that jump when k is a whole number of cycles, so the frequency is
  // rounded to the nearest integer to keep the traveling wave seamless.
  float waveFreq = floor(2.0 + uWave * 4.0 + 0.5);
  float wavePhase = atan(p.y, p.x) * waveFreq - uTime * uSpeed * 1.5;
  float wave = 0.75 + 0.25 * sin(wavePhase);

  float colorPhase = fract(uTime * uColorCycle * 0.1 +
                            atan(p.y, p.x) / (2.0 * 3.14159265));
  vec4 color = rampColor(colorPhase);

  float alpha = glow * maskAlpha * wave;
  fragColor = vec4(color.rgb, color.a * alpha);
}
