# liquid_glow — Shape-Based Presets Extension — Design Spec

Date: 2026-07-15
Status: Approved
Extends: `docs/superpowers/specs/2026-07-14-liquid-glow-design.md`

## Summary

Adds two new `LiquidGlow` presets that render discrete, independently-moving
SDF (signed-distance-field) shapes blended into a "liquid merge" look via
smooth-min blending, instead of the existing domain-warped-noise gradient:

- `LiquidGlowPreset.darkGlow({required Color backgroundColor})` — a solid
  dark background (developer-supplied color) with 3 glowing circular orbs
  floating across it.
- `LiquidGlowPreset.floatingShapes()` — a solid white background with 5
  shapes cycling through 3 kinds (triangle, rounded square, circle),
  rendered translucent/soft-edged so overlapping shapes appear to merge
  like liquid.

Both remain simple, argument-light named presets (matching `.aurora()` /
`.lavaLamp()` / `.cyberpunk()`), consistent with `LiquidGlow`'s existing
public API — no new widget, no new controller API.

## Goals

- Two new visually distinct `LiquidGlowPreset` options, each backed by its
  own independent GLSL shader (not the existing noise shader).
- Shapes/orbs move with per-shape *varied* motion — some orbit a center
  point, some bounce vertically, some travel back-and-forth between two
  screen points — so the whole composition reads as organically "floating"
  rather than uniformly rotating. This motion variety applies to both new
  presets (both `darkGlow`'s 3 orbs and `floatingShapes`' 5 shapes).
- Shape/orb merging uses real SDF smooth-min blending inside the shader
  (a genuine metaball effect), not a post-process blur+contrast composite
  layer — consistent with the project's shader-first performance
  principle and avoiding `BackdropFilter`'s framebuffer-sampling cost.
- Reuse all existing infrastructure: `LiquidGlowController`
  (play/pause/stop/speed/intensity), `GlowTickerMixin` (reduce-motion,
  backgrounding, route-coverage, `TickerMode` pausing), `ShaderWarmCache`.

## Non-Goals

- Runtime customization of shape count, shape kinds, or colors for either
  preset (matches the existing "simple named preset" pattern — `.custom()`
  remains the escape hatch for the noise-based renderer only; these two
  new presets do not get a `.custom()`-style variant in this iteration).
- Customizable background color for `floatingShapes` (fixed white, per
  its literal "oq fonda" spec — only `darkGlow` exposes `backgroundColor`,
  since only that was explicitly requested as developer-supplied).
- Touch reaction for these two presets (the existing `enableTouchReaction`
  touch-ripple behavior is specific to the noise shader's `uTouch`
  uniform; the two new shaders do not implement it in this iteration).
- Runtime preset switching on a single controller instance. Not new here:
  `LiquidGlowController.preset` is already `final`/immutable post-
  construction (spec 2026-07-14), so which shader a given `LiquidGlow`
  instance uses is decided once, at controller-construction time.

## Architecture

### `LiquidGlowPreset` gains an internal `kind`

`LiquidGlowPreset` gets a private `_LiquidGlowPresetKind` field (`noise`,
`darkOrbs`, `floatingShapes`) set by each named constructor. The public API
is unchanged — `colors`/`baseSpeed`/`noiseScale` remain the only fields
used by the noise-based presets; `darkGlow`/`floatingShapes` populate
different internal fields (`backgroundColor` for `darkGlow`) and leave
`colors`/`baseSpeed`/`noiseScale` at harmless defaults (unused by their
shaders). `LiquidGlowController`, `LiquidGlowPainter`'s existing contract,
and every existing preset's behavior are unaffected.

### Two new independent shaders, two new painters

Following the codebase's established one-shader-one-painter convention
(`LiquidGlowPainter`↔`liquid_fluid.frag`, `SiriGlowPainter`↔
`siri_edge.frag`):

- `shaders/liquid_orbs.frag` ↔ new `LiquidOrbsPainter`
- `shaders/liquid_shapes.frag` ↔ new `LiquidShapesPainter`

`_LiquidGlowState` (in `liquid_glow_widget.dart`) picks which shader to
load from `ShaderWarmCache` and which painter to construct based on
`widget.controller.preset.kind`, decided once in `initState` (consistent
with `preset` being immutable). The three shaders/painters are otherwise
fully independent — no shared shader code, matching the "two independent
systems" decision.

### Shared motion math (Dart-side, not shader-side)

Both new shaders need N animated 2D positions per frame (3 for
`darkGlow`, 5 for `floatingShapes`). Rather than duplicating orbit/bounce/
travel formulas inside two GLSL files, position computation lives in one
new pure-Dart module, `lib/src/liquid_glow/shape_motion.dart`:

```dart
enum ShapeMotionKind { orbital, bounce, travel }

@immutable
class ShapeMotionParams {
  const ShapeMotionParams.orbital({
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.orbital,
        pointA = Offset.zero,
        pointB = Offset.zero;

  const ShapeMotionParams.bounce({
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.bounce,
        pointA = Offset.zero,
        pointB = Offset.zero;

  const ShapeMotionParams.travel({
    required this.pointA,
    required this.pointB,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.travel,
        center = Offset.zero,
        radius = 0;

  final ShapeMotionKind kind;
  final Offset center;   // orbital: orbit center. bounce: base position.
  final double radius;   // orbital: orbit radius. bounce: bounce height.
  final double speed;    // multiplier applied on top of controller.speed
  final double phase;    // time offset so shapes don't move in sync
  final Offset pointA;   // travel: ping-pong endpoint A (normalized 0..1)
  final Offset pointB;   // travel: ping-pong endpoint B (normalized 0..1)
}

/// Computes a shape's normalized (0..1) position at elapsed time [t]
/// (seconds), scaled by the controller's live [speed].
Offset computeShapePosition(ShapeMotionParams p, double t, double speed) {
  final effectiveT = t * speed;
  switch (p.kind) {
    case ShapeMotionKind.orbital:
      final angle = effectiveT * p.speed + p.phase;
      return p.center + Offset(cos(angle), sin(angle)) * p.radius;
    case ShapeMotionKind.bounce:
      final bounceT = effectiveT * p.speed + p.phase;
      return Offset(p.center.dx, p.center.dy - sin(bounceT).abs() * p.radius);
    case ShapeMotionKind.travel:
      final raw = (effectiveT * p.speed + p.phase) % 1.0;
      final triangle = raw < 0.5 ? raw * 2 : 2 - raw * 2;
      return Offset.lerp(p.pointA, p.pointB, triangle)!;
  }
}
```

This is pure, deterministic, and independently unit-testable (given a
`ShapeMotionParams` and `t`, the output position is exact and
reproducible) — no shader/asset loading needed to test motion correctness.

### `darkGlow` orb configuration (fixed, internal to `LiquidOrbsPainter`)

3 orbs, each a different motion kind (per the "apply variety to both
presets" decision):

| Orb | Motion | Params |
|---|---|---|
| 0 | orbital | center (0.5, 0.5), radius 0.15, phase 0 |
| 1 | bounce | center (0.3, 0.6), radius 0.12, phase 2.1 |
| 2 | travel | (0.8, 0.2) ↔ (0.3, 0.8), phase 4.2 |

2 fixed glow accent colors (violet `0xFF7F5AF0` and cyan `0xFF2CB1E0`,
matching `SiriGlowEdge`'s default palette for visual family resemblance),
blended by proximity where orbs overlap.

### `floatingShapes` shape configuration (fixed, internal to
`LiquidShapesPainter`)

5 shapes, kind cycling `[triangle, roundedSquare, circle, triangle,
roundedSquare]`, motion cycling `[orbital, bounce, travel, orbital,
bounce]` with distinct centers/phases so no two shapes visually overlap
in timing:

| Shape | Kind | Motion | Params |
|---|---|---|---|
| 0 | triangle | orbital | center (0.35, 0.4), radius 0.18, phase 0 |
| 1 | roundedSquare | bounce | center (0.65, 0.5), radius 0.15, phase 1.5 |
| 2 | circle | travel | (0.85, 0.15) ↔ (0.5, 0.75), phase 3.0 |
| 3 | triangle | orbital | center (0.6, 0.7), radius 0.12, phase 2.4 |
| 4 | roundedSquare | bounce | center (0.25, 0.65), radius 0.1, phase 0.8 |

3 fixed pastel colors (one per shape-kind, reused across cycling
instances), each with reduced alpha (~0.55) for the translucent "liquid
glass" look; solid white background hardcoded in the shader (not a
uniform, since it is not customizable per the Non-Goals section).

## Shader Design

### `shaders/liquid_orbs.frag`

Standard Flutter fragment-shader boilerplate (`#version 460 core`,
`#include <flutter/runtime_effect.glsl>`, `FlutterFragCoord()`), matching
the two existing shaders. SDF circle: `length(p - center) - radius`.
Three orb distances combined via Inigo-Quilez-style smooth-min
(`opSmoothUnion`), producing one merged distance field; final color mixes
the two accent colors by which orb is closer at each point, then mixes
merged-shape-color with `uBackgroundColor` using a `smoothstep`-based glow
falloff around the zero-distance boundary (soft edges, no hard cutoff —
this is where the "blur" quality the spec asked for comes from, achieved
as an SDF falloff rather than a separate blur pass).

Uniform contract (24 floats, indices 0-23), order load-bearing for
`LiquidOrbsPainter`:

1. `uSize` (vec2) → 0-1
2. `uTime` (float) → 2
3. `uSpeed` (float) → 3
4. `uIntensity` (float) → 4 (scales orb radius/glow softness)
5. `uBackgroundColor` (vec4) → 5-8
6. `uOrbColor0` (vec4) → 9-12
7. `uOrbColor1` (vec4) → 13-16
8. `uOrbPos0`, `uOrbPos1`, `uOrbPos2` (vec2 each) → 17-22
9. `uOrbRadius` (float) → 23

### `shaders/liquid_shapes.frag`

Same boilerplate. Three SDF primitives: circle (as above), axis-aligned
rounded box (`sdRoundBox`, standard IQ formula), equilateral triangle
(`sdEquilateralTriangle`, standard IQ formula) — the shape-kind-per-slot
assignment (`[triangle, roundedSquare, circle, triangle, roundedSquare]`)
is hardcoded in the shader body (five explicit SDF calls at fixed
positions/kinds), since it is not runtime-configurable. All five
distances combined via the same `opSmoothUnion` chain; color picked by
nearest shape's assigned kind-color, alpha modulated by the merged
distance's `smoothstep` falloff for the translucent edge look, composited
over hardcoded solid white.

Uniform contract (28 floats, indices 0-27):

1. `uSize` (vec2) → 0-1
2. `uTime` (float) → 2
3. `uSpeed` (float) → 3
4. `uIntensity` (float) → 4
5. `uShapeColor0`, `uShapeColor1`, `uShapeColor2` (vec4 each, one per
   shape-kind) → 5-16
6. `uShapePos0`..`uShapePos4` (vec2 each, five positions) → 17-26
7. `uShapeSize` (float) → 27

## Public API Additions

```dart
class LiquidGlowPreset {
  // ...existing .aurora()/.lavaLamp()/.cyberpunk()/.custom() unchanged...

  /// Solid dark background (yours to choose) with 3 glowing orbs
  /// floating across it — orbiting, bouncing, and drifting corner-to-
  /// center in a mix of independent motions.
  const LiquidGlowPreset.darkGlow({required Color backgroundColor});

  /// Solid white background with 5 shapes (triangles, rounded squares,
  /// circles) that merge into each other like liquid as they float.
  const LiquidGlowPreset.floatingShapes();
}
```

Both remain usable exactly like existing presets:

```dart
LiquidGlowController(preset: const LiquidGlowPreset.darkGlow(
  backgroundColor: Color(0xFF0B0F1A),
));
LiquidGlowController(preset: const LiquidGlowPreset.floatingShapes());
```

## Testing Plan

- `test/liquid_glow/shape_motion_test.dart` — pure unit tests for
  `computeShapePosition` covering all 3 `ShapeMotionKind`s: orbital
  returns points on the expected circle, bounce stays within
  `[center.dy - radius, center.dy]` and is periodic, travel ping-pongs
  between `pointA`/`pointB` and hits both endpoints over one period.
- `test/liquid_glow/liquid_glow_preset_test.dart` — extended with cases
  confirming `.darkGlow()`/`.floatingShapes()` construct successfully and
  expose the `backgroundColor` `darkGlow` was given.
- `test/shaders/shader_load_test.dart` — extended with two more compile-
  check cases (`liquid_orbs`, `liquid_shapes`), following the existing
  pattern.
- `test/widget/liquid_glow_lifecycle_test.dart` (or a new adjacent file)
  — a widget test per new preset confirming the correct painter type
  (`LiquidOrbsPainter` / `LiquidShapesPainter`) is constructed once the
  shader loads, and that reduce-motion/backgrounding still freeze/pause
  them (reusing `GlowTickerMixin`, already proven correct — this is a
  regression check, not new gating logic).
- No golden/pixel tests (unchanged project convention). Given the
  previous session's live-verification findings (a shader-loading bug
  and a widget-tree bug that only surfaced on a real simulator), the
  implementation plan for this extension must include an explicit
  manual-verification step running the example app on a real
  simulator/device before considering the work complete — automated
  tests passing is necessary but was already proven insufficient alone.

## Key Decisions Log

| Decision | Choice | Reason |
|---|---|---|
| Placement | New `LiquidGlowPreset` variants inside existing `LiquidGlow` | Reuses controller/lifecycle/a11y infrastructure; no new widget surface |
| Merge technique | GLSL SDF smooth-min | Highest performance (120fps target), consistent with shader-first principle; rejected `BackdropFilter` blur+contrast for its framebuffer-sampling cost |
| Shared system? | Two independent shaders/painters, not unified | User's explicit choice — allows each to evolve independently |
| Shape count | `darkGlow`: fixed 3 orbs. `floatingShapes`: fixed 5 shapes, 3 kinds | Matches "simple named preset" pattern (no `.custom()` variant this iteration) |
| Motion | 3 kinds (orbital/bounce/travel), computed in Dart, applied to both presets | User-requested variety ("qaysidiri sakrab, qaysidiri burchakdan markazga"); Dart-side keeps math unit-testable and shaders simple |
| `floatingShapes` background | Fixed white, not customizable | Matches literal "oq fonda" request; only `darkGlow`'s background was explicitly requested as developer-supplied |
| Touch reaction | Not implemented for either new preset | Not requested; avoids scope creep onto an unrelated uniform contract |
