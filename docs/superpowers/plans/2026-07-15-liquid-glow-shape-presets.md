# liquid_glow Shape Presets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add two new `LiquidGlowPreset` variants — `.darkGlow()` (3 orbiting/bouncing/traveling glow orbs on a developer-supplied dark background) and `.floatingShapes()` (5 triangle/square/circle SDF shapes merging like liquid on a white background) — each backed by its own independent GLSL shader.

**Architecture:** `LiquidGlowPreset` gains an internal `kind` (`LiquidGlowPresetKind`) that `_LiquidGlowState` uses to pick which of three shaders to load and which painter (`LiquidGlowPainter` / `LiquidOrbsPainter` / `LiquidShapesPainter`) to construct. Shape/orb positions are computed each frame by a shared, pure, unit-testable Dart motion module (`shape_motion.dart`) and passed to the shaders as plain position uniforms — the shaders themselves only do SDF distance + smooth-min blending + color, no motion math.

**Tech Stack:** Same as the base package — Flutter SDK only, `dart:ui` `FragmentProgram`, GLSL fragment shaders, `flutter_test`.

## Global Constraints

- Flutter >= 3.19.0, Dart >= 3.3.0 (unchanged package floor).
- No third-party runtime dependencies.
- iOS + Android only.
- No golden/visual-regression tests — verify shader compilation via `shader_load_test.dart` and verify the actual visuals by running the example app on a real simulator/device before considering this plan complete. The previous session found two real bugs (a shader asset-path bug and a widget-tree closure bug) that only surfaced on-device despite a fully green automated test suite — automated tests passing is necessary but not sufficient here.
- Merge technique is GLSL SDF smooth-min (`opSmoothUnion`), not `BackdropFilter` blur+contrast — decided for performance (spec `2026-07-15-liquid-glow-shape-presets-design.md`, Key Decisions Log).
- `darkGlow`/`floatingShapes` are simple named presets with fixed internal defaults; only `darkGlow`'s `backgroundColor` is developer-supplied. Neither preset customizes shape count/colors/kinds in this iteration, and neither implements touch reaction.
- The two new shaders are fully independent of each other and of `liquid_fluid.frag` — no shared shader code (explicit user decision during brainstorming).

---

## Task 1: Shared shape-motion math

**Files:**
- Create: `lib/src/liquid_glow/shape_motion.dart`
- Test: `test/liquid_glow/shape_motion_test.dart`

**Interfaces:**
- Produces: `enum ShapeMotionKind { orbital, bounce, travel }`; `class ShapeMotionParams` with named const constructors `.orbital({required center, required radius, required speed, required phase})`, `.bounce({required center, required radius, required speed, required phase})`, `.travel({required pointA, required pointB, required speed, required phase})`; top-level `Offset computeShapePosition(ShapeMotionParams params, double t, double speed)`. Consumed by Tasks 4, 6, and 7.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/shape_motion.dart';

void main() {
  group('orbital', () {
    test('stays on the configured circle around center', () {
      const params = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5),
        radius: 0.2,
        speed: 1.0,
        phase: 0,
      );
      for (final t in [0.0, 0.7, 3.3, 10.0]) {
        final pos = computeShapePosition(params, t, 1.0);
        final dist = (pos - params.center).distance;
        expect(dist, closeTo(0.2, 1e-6));
      }
    });

    test('speed multiplier scales angular velocity', () {
      const slow = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5), radius: 0.2, speed: 1.0, phase: 0);
      const fast = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5), radius: 0.2, speed: 2.0, phase: 0);
      final posSlow = computeShapePosition(slow, 1.0, 1.0);
      final posFast = computeShapePosition(fast, 1.0, 1.0);
      // Fast orbit at t=1 should match slow orbit's angle at t=2.
      final posSlowAtDoubleT = computeShapePosition(slow, 2.0, 1.0);
      expect(posFast.dx, closeTo(posSlowAtDoubleT.dx, 1e-6));
      expect(posFast.dy, closeTo(posSlowAtDoubleT.dy, 1e-6));
      expect(posSlow, isNot(equals(posFast)));
    });
  });

  group('bounce', () {
    test('y stays within [center.dy - radius, center.dy], x is fixed', () {
      const params = ShapeMotionParams.bounce(
        center: Offset(0.4, 0.7),
        radius: 0.15,
        speed: 1.0,
        phase: 0,
      );
      for (final t in [0.0, 0.5, 1.0, 2.0, 5.0]) {
        final pos = computeShapePosition(params, t, 1.0);
        expect(pos.dx, 0.4);
        expect(pos.dy, lessThanOrEqualTo(0.7));
        expect(pos.dy, greaterThanOrEqualTo(0.7 - 0.15 - 1e-9));
      }
    });

    test('is periodic with period pi (since it uses |sin|)', () {
      const params = ShapeMotionParams.bounce(
        center: Offset(0.4, 0.7), radius: 0.15, speed: 1.0, phase: 0);
      final a = computeShapePosition(params, 0.6, 1.0);
      final b = computeShapePosition(params, 0.6 + math.pi, 1.0);
      expect(a.dy, closeTo(b.dy, 1e-6));
    });
  });

  group('travel', () {
    test('reaches pointA at the start of each period and pointB at the '
        'midpoint', () {
      const params = ShapeMotionParams.travel(
        pointA: Offset(0.8, 0.2),
        pointB: Offset(0.3, 0.8),
        speed: 1.0,
        phase: 0,
      );
      final atStart = computeShapePosition(params, 0.0, 1.0);
      final atMid = computeShapePosition(params, 0.5, 1.0);
      expect(atStart.dx, closeTo(0.8, 1e-6));
      expect(atStart.dy, closeTo(0.2, 1e-6));
      expect(atMid.dx, closeTo(0.3, 1e-6));
      expect(atMid.dy, closeTo(0.8, 1e-6));
    });

    test('ping-pongs back to pointA by the end of the period', () {
      const params = ShapeMotionParams.travel(
        pointA: Offset(0.8, 0.2), pointB: Offset(0.3, 0.8),
        speed: 1.0, phase: 0);
      final nearEnd = computeShapePosition(params, 0.999, 1.0);
      expect(nearEnd.dx, closeTo(0.8, 0.01));
      expect(nearEnd.dy, closeTo(0.2, 0.01));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/liquid_glow/shape_motion_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/liquid_glow/shape_motion.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How a shape/orb's position moves over time. Positions are always
/// normalized 0..1, matching the widget's local coordinate space.
enum ShapeMotionKind { orbital, bounce, travel }

/// Parameters for one shape/orb's motion. Construct via [orbital],
/// [bounce], or [travel] — the fields relevant to other kinds are unused
/// zero/identity values, kept only so [computeShapePosition] can accept a
/// single uniform parameter type.
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

  /// orbital: orbit center. bounce: base position (x is fixed, y bounces
  /// upward from here). Unused for travel.
  final Offset center;

  /// orbital: orbit radius. bounce: bounce height. Unused for travel.
  final double radius;

  /// Per-shape multiplier applied on top of the caller-supplied global
  /// speed in [computeShapePosition].
  final double speed;

  /// Time offset (radians for orbital/bounce, a 0..1-ish offset for
  /// travel) so shapes with identical motion kinds don't move in sync.
  final double phase;

  /// travel: ping-pong endpoint A (normalized 0..1). Unused otherwise.
  final Offset pointA;

  /// travel: ping-pong endpoint B (normalized 0..1). Unused otherwise.
  final Offset pointB;
}

/// Computes a shape's normalized (0..1) position at elapsed time [t]
/// seconds, additionally scaled by the caller's live [speed] (typically
/// `LiquidGlowController.speed`).
Offset computeShapePosition(ShapeMotionParams params, double t, double speed) {
  final effectiveT = t * speed;
  switch (params.kind) {
    case ShapeMotionKind.orbital:
      final angle = effectiveT * params.speed + params.phase;
      return params.center +
          Offset(math.cos(angle), math.sin(angle)) * params.radius;
    case ShapeMotionKind.bounce:
      final bounceT = effectiveT * params.speed + params.phase;
      return Offset(
        params.center.dx,
        params.center.dy - math.sin(bounceT).abs() * params.radius,
      );
    case ShapeMotionKind.travel:
      final raw = (effectiveT * params.speed + params.phase) % 1.0;
      final triangle = raw < 0.5 ? raw * 2 : 2 - raw * 2;
      return Offset.lerp(params.pointA, params.pointB, triangle)!;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/liquid_glow/shape_motion_test.dart`
Expected: PASS (6 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/liquid_glow/shape_motion.dart test/liquid_glow/shape_motion_test.dart
git commit -m "feat: add shared shape-motion math (orbital/bounce/travel)"
```

---

## Task 2: `LiquidGlowPreset` — `kind`, `.darkGlow()`, `.floatingShapes()`

**Files:**
- Modify: `lib/src/liquid_glow/liquid_glow_preset.dart`
- Modify: `test/liquid_glow/liquid_glow_preset_test.dart`

**Interfaces:**
- Consumes: nothing new.
- Produces: `enum LiquidGlowPresetKind { noise, darkOrbs, floatingShapes }`; `LiquidGlowPreset` gains `final Color? backgroundColor` and `final LiquidGlowPresetKind kind` fields (all four existing constructors set `kind: LiquidGlowPresetKind.noise` and `backgroundColor: null`), plus two new const constructors `.darkGlow({required Color backgroundColor})` and `.floatingShapes()`. Consumed by Tasks 4, 6, 7.

- [ ] **Step 1: Write the failing test**

Add to the end of `test/liquid_glow/liquid_glow_preset_test.dart` (inside the existing `void main() { ... }`, alongside the existing two `test(...)` calls — do not remove them):

```dart
  test('darkGlow carries the given backgroundColor and darkOrbs kind', () {
    const preset = LiquidGlowPreset.darkGlow(backgroundColor: Color(0xFF0B0F1A));
    expect(preset.backgroundColor, const Color(0xFF0B0F1A));
    expect(preset.kind, LiquidGlowPresetKind.darkOrbs);
  });

  test('floatingShapes has no backgroundColor and floatingShapes kind', () {
    const preset = LiquidGlowPreset.floatingShapes();
    expect(preset.backgroundColor, isNull);
    expect(preset.kind, LiquidGlowPresetKind.floatingShapes);
  });

  test('noise-based presets default to kind noise with no backgroundColor',
      () {
    for (final preset in [
      const LiquidGlowPreset.aurora(),
      const LiquidGlowPreset.lavaLamp(),
      const LiquidGlowPreset.cyberpunk(),
    ]) {
      expect(preset.kind, LiquidGlowPresetKind.noise);
      expect(preset.backgroundColor, isNull);
    }
  });
```

Also add `LiquidGlowPresetKind` to the existing import (the file already imports `package:liquid_glow/src/liquid_glow/liquid_glow_preset.dart`, which will export both symbols — no new import line needed).

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/liquid_glow/liquid_glow_preset_test.dart`
Expected: FAIL — `Error: The getter 'backgroundColor' isn't defined for the class 'LiquidGlowPreset'` (or `kind`/`LiquidGlowPresetKind` not found)

- [ ] **Step 3: Write minimal implementation**

Replace the full contents of `lib/src/liquid_glow/liquid_glow_preset.dart` with:

```dart
import 'package:flutter/painting.dart';

/// Which shader-backed rendering algorithm a [LiquidGlowPreset] uses.
/// Exposed for `LiquidGlow`'s internal shader/painter dispatch — most
/// consumers only need the named preset constructors, not this directly.
enum LiquidGlowPresetKind { noise, darkOrbs, floatingShapes }

/// A named color/speed/scale configuration for [LiquidGlow].
class LiquidGlowPreset {
  /// Northern-lights palette: green, purple, blue. Slow, ambient motion.
  const LiquidGlowPreset.aurora()
      : colors = const [
          Color(0xFF00C9A7),
          Color(0xFF6A5ACD),
          Color(0xFF1E90FF),
        ],
        baseSpeed = 0.6,
        noiseScale = 1.0,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// Dense, slow-moving warm colors.
  const LiquidGlowPreset.lavaLamp()
      : colors = const [
          Color(0xFFB3001B),
          Color(0xFFFF4D00),
          Color(0xFFFFA500),
        ],
        baseSpeed = 0.3,
        noiseScale = 1.6,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// Aggressive neon pink/cyan animation.
  const LiquidGlowPreset.cyberpunk()
      : colors = const [
          Color(0xFFFF00E5),
          Color(0xFF00F0FF),
          Color(0xFF7000FF),
        ],
        baseSpeed = 1.4,
        noiseScale = 0.8,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// A user-defined preset. [colors] must have between 2 and 6 entries.
  ///
  /// Not `const`: `List.length` cannot be accessed in a constant
  /// expression in Dart, so a `const` constructor here would fail to
  /// compile at any `const LiquidGlowPreset.custom(...)` call site
  /// (verified: `const_eval_property_access`). This was already fixed
  /// once (commit `0c06350`) after live testing surfaced it; retained
  /// here as a non-const constructor for the same reason.
  LiquidGlowPreset.custom({
    required this.colors,
    required this.baseSpeed,
    required this.noiseScale,
  })  : backgroundColor = null,
        kind = LiquidGlowPresetKind.noise,
        assert(
          colors.length >= 2 && colors.length <= 6,
          'colors must have between 2 and 6 entries',
        );

  /// A solid dark background (yours to choose) with 3 glowing orbs
  /// floating across it — orbiting, bouncing, and drifting corner-to-
  /// center in a mix of independent motions.
  const LiquidGlowPreset.darkGlow({required Color this.backgroundColor})
      : colors = const [],
        baseSpeed = 0,
        noiseScale = 0,
        kind = LiquidGlowPresetKind.darkOrbs;

  /// Solid white background with 5 shapes (triangles, rounded squares,
  /// circles) that merge into each other like liquid as they float.
  const LiquidGlowPreset.floatingShapes()
      : colors = const [],
        baseSpeed = 0,
        noiseScale = 0,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.floatingShapes;

  final List<Color> colors;
  final double baseSpeed;
  final double noiseScale;

  /// Only set (non-null) for [LiquidGlowPresetKind.darkOrbs] (i.e.
  /// presets built via [darkGlow]).
  final Color? backgroundColor;

  final LiquidGlowPresetKind kind;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/liquid_glow/liquid_glow_preset_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the full suite to check for regressions**

Run: `flutter test`
Expected: PASS (all tests, including every existing `LiquidGlowController`/`LiquidGlow` test that constructs a preset)

- [ ] **Step 6: Commit**

```bash
git add lib/src/liquid_glow/liquid_glow_preset.dart test/liquid_glow/liquid_glow_preset_test.dart
git commit -m "feat: add LiquidGlowPresetKind, LiquidGlowPreset.darkGlow/.floatingShapes"
```

---

## Task 3: `liquid_orbs.frag` shader

**Files:**
- Create: `shaders/liquid_orbs.frag`
- Modify: `pubspec.yaml` (extend `flutter: shaders:` list)
- Modify: `lib/src/core/shader_warm_cache.dart` (add `liquidOrbs` asset-key constant)
- Modify: `test/shaders/shader_load_test.dart` (add a `liquid_orbs` compile-check case)

**Interfaces:**
- Consumes: `ShaderWarmCache.load` (unchanged signature).
- Produces: `ShaderWarmCache.liquidOrbs` constant (`'shaders/liquid_orbs.frag'`); a compiled shader with this 24-float uniform contract (indices 0-23), consumed by Task 4's `LiquidOrbsPainter`:
  1. `uSize` (vec2) → 0-1
  2. `uTime` (float) → 2
  3. `uSpeed` (float) → 3
  4. `uIntensity` (float) → 4
  5. `uBackgroundColor` (vec4) → 5-8
  6. `uOrbColor0` (vec4) → 9-12
  7. `uOrbColor1` (vec4) → 13-16
  8. `uOrbPos0`, `uOrbPos1`, `uOrbPos2` (vec2 each) → 17-22
  9. `uOrbRadius` (float) → 23

- [ ] **Step 1: Extend the failing test**

Add to `test/shaders/shader_load_test.dart` (alongside the existing two `test(...)` calls):

```dart
  test('liquid_orbs shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidOrbs);
    expect(program, isNotNull);
  });
```

- [ ] **Step 2: Run test to verify the new case fails**

Run: `flutter test test/shaders/shader_load_test.dart`
Expected: FAIL on the new `liquid_orbs` case — `ShaderWarmCache.liquidOrbs` not found (compile error), or once that's added, asset-not-found

- [ ] **Step 3: Add the asset-key constant**

In `lib/src/core/shader_warm_cache.dart`, add alongside the existing `liquidFluid`/`siriEdge` constants:

```dart
  /// Asset key for the LiquidGlow dark-orbs shader (registered in
  /// `pubspec.yaml` once `shaders/liquid_orbs.frag` exists).
  static const String liquidOrbs = 'shaders/liquid_orbs.frag';
```

- [ ] **Step 4: Create `shaders/liquid_orbs.frag`**

```glsl
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
```

- [ ] **Step 5: Register the shader in `pubspec.yaml`**

Extend the `flutter: shaders:` list to include the new file (keep the existing two entries):

```yaml
flutter:
  shaders:
    - shaders/liquid_fluid.frag
    - shaders/siri_edge.frag
    - shaders/liquid_orbs.frag
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter pub get && flutter test test/shaders/shader_load_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Commit**

```bash
git add shaders/liquid_orbs.frag pubspec.yaml lib/src/core/shader_warm_cache.dart test/shaders/shader_load_test.dart
git commit -m "feat: add liquid_orbs.frag SDF-merged-orbs shader"
```

---

## Task 4: `LiquidOrbsPainter`

**Files:**
- Create: `lib/src/liquid_glow/liquid_orbs_painter.dart`
- Test: `test/liquid_glow/liquid_orbs_painter_test.dart`

**Interfaces:**
- Consumes: `LiquidGlowController` (`speed`, `intensity`, `preset`), `ShapeMotionParams`/`computeShapePosition` (Task 1), the `shaders/liquid_orbs.frag` uniform contract (Task 3).
- Produces: `class LiquidOrbsPainter extends CustomPainter` with constructor `{required program, required timeSeconds, required controller, required orbPositions}` and `static const List<ShapeMotionParams> motions` (exactly 3 entries). Consumed by Task 7.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_orbs_painter.dart';
import 'package:liquid_glow/src/liquid_glow/shape_motion.dart';

void main() {
  test('motions has exactly 3 entries, one of each motion kind', () {
    expect(LiquidOrbsPainter.motions, hasLength(3));
    final kinds = LiquidOrbsPainter.motions.map((m) => m.kind).toSet();
    expect(kinds, {
      ShapeMotionKind.orbital,
      ShapeMotionKind.bounce,
      ShapeMotionKind.travel,
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/liquid_glow/liquid_orbs_painter_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/liquid_glow/liquid_orbs_painter.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../controller/liquid_glow_controller.dart';
import 'shape_motion.dart';

/// Paints the LiquidGlow dark-orbs shader, packing uniforms in the exact
/// order declared in `shaders/liquid_orbs.frag`.
class LiquidOrbsPainter extends CustomPainter {
  LiquidOrbsPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.orbPositions,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;

  /// Normalized (0..1) positions of the 3 orbs, in uniform order. Compute
  /// with `computeShapePosition` against [motions].
  final List<Offset> orbPositions;

  static const Color _orbColor0 = Color(0xFF7F5AF0);
  static const Color _orbColor1 = Color(0xFF2CB1E0);
  static const double _orbRadius = 0.16;

  /// Fixed per-orb motion config: one of each kind, distinct phases so
  /// the three orbs never move in visual lockstep.
  static const List<ShapeMotionParams> motions = [
    ShapeMotionParams.orbital(
      center: Offset(0.5, 0.5), radius: 0.15, speed: 1.0, phase: 0),
    ShapeMotionParams.bounce(
      center: Offset(0.3, 0.6), radius: 0.12, speed: 1.0, phase: 2.1),
    ShapeMotionParams.travel(
      pointA: Offset(0.8, 0.2), pointB: Offset(0.3, 0.8),
      speed: 1.0, phase: 4.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    // darkGlow's constructor requires backgroundColor, so it is always
    // set on any preset that produces a LiquidOrbsPainter.
    final background = controller.preset.backgroundColor!;

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, background.red / 255)
      ..setFloat(i++, background.green / 255)
      ..setFloat(i++, background.blue / 255)
      ..setFloat(i++, background.alpha / 255)
      ..setFloat(i++, _orbColor0.red / 255)
      ..setFloat(i++, _orbColor0.green / 255)
      ..setFloat(i++, _orbColor0.blue / 255)
      ..setFloat(i++, _orbColor0.alpha / 255)
      ..setFloat(i++, _orbColor1.red / 255)
      ..setFloat(i++, _orbColor1.green / 255)
      ..setFloat(i++, _orbColor1.blue / 255)
      ..setFloat(i++, _orbColor1.alpha / 255);

    for (final pos in orbPositions) {
      shader
        ..setFloat(i++, pos.dx)
        ..setFloat(i++, pos.dy);
    }

    shader.setFloat(i++, _orbRadius);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidOrbsPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.orbPositions != orbPositions ||
        oldDelegate.controller != controller;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/liquid_glow/liquid_orbs_painter_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/src/liquid_glow/liquid_orbs_painter.dart test/liquid_glow/liquid_orbs_painter_test.dart
git commit -m "feat: add LiquidOrbsPainter"
```

---

## Task 5: `liquid_shapes.frag` shader

**Files:**
- Create: `shaders/liquid_shapes.frag`
- Modify: `pubspec.yaml` (extend `flutter: shaders:` list)
- Modify: `lib/src/core/shader_warm_cache.dart` (add `liquidShapes` asset-key constant)
- Modify: `test/shaders/shader_load_test.dart` (add a `liquid_shapes` compile-check case)

**Interfaces:**
- Produces: `ShaderWarmCache.liquidShapes` constant (`'shaders/liquid_shapes.frag'`); a compiled shader with this 28-float uniform contract (indices 0-27), consumed by Task 6's `LiquidShapesPainter`:
  1. `uSize` (vec2) → 0-1
  2. `uTime` (float) → 2
  3. `uSpeed` (float) → 3
  4. `uIntensity` (float) → 4
  5. `uShapeColor0`, `uShapeColor1`, `uShapeColor2` (vec4 each) → 5-16
  6. `uShapePos0`..`uShapePos4` (vec2 each) → 17-26
  7. `uShapeSize` (float) → 27

- [ ] **Step 1: Extend the failing test**

Add to `test/shaders/shader_load_test.dart`:

```dart
  test('liquid_shapes shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidShapes);
    expect(program, isNotNull);
  });
```

- [ ] **Step 2: Run test to verify the new case fails**

Run: `flutter test test/shaders/shader_load_test.dart`
Expected: FAIL on the new `liquid_shapes` case

- [ ] **Step 3: Add the asset-key constant**

In `lib/src/core/shader_warm_cache.dart`, add:

```dart
  /// Asset key for the LiquidGlow floating-shapes shader (registered in
  /// `pubspec.yaml` once `shaders/liquid_shapes.frag` exists).
  static const String liquidShapes = 'shaders/liquid_shapes.frag';
```

- [ ] **Step 4: Create `shaders/liquid_shapes.frag`**

```glsl
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
  float blend = 0.05 + 0.03 * clamp(uIntensity, 0.0, 2.0);

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

  float shimmer = 0.95 + 0.05 * sin(uTime * uSpeed * 1.5);
  float alpha = clamp(
    (1.0 - smoothstep(-blend, blend * 2.0, merged)) * 0.55 * shimmer,
    0.0, 1.0);

  vec4 background = vec4(1.0, 1.0, 1.0, 1.0);
  fragColor = mix(background, vec4(color.rgb, 1.0), alpha);
}
```

- [ ] **Step 5: Register the shader in `pubspec.yaml`**

Extend the `flutter: shaders:` list to include the new file (keep the existing three entries):

```yaml
flutter:
  shaders:
    - shaders/liquid_fluid.frag
    - shaders/siri_edge.frag
    - shaders/liquid_orbs.frag
    - shaders/liquid_shapes.frag
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter pub get && flutter test test/shaders/shader_load_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add shaders/liquid_shapes.frag pubspec.yaml lib/src/core/shader_warm_cache.dart test/shaders/shader_load_test.dart
git commit -m "feat: add liquid_shapes.frag SDF-merged-shapes shader"
```

---

## Task 6: `LiquidShapesPainter`

**Files:**
- Create: `lib/src/liquid_glow/liquid_shapes_painter.dart`
- Test: `test/liquid_glow/liquid_shapes_painter_test.dart`

**Interfaces:**
- Consumes: `LiquidGlowController` (`speed`, `intensity`), `ShapeMotionParams`/`computeShapePosition` (Task 1), the `shaders/liquid_shapes.frag` uniform contract (Task 5).
- Produces: `class LiquidShapesPainter extends CustomPainter` with constructor `{required program, required timeSeconds, required controller, required shapePositions}` and `static const List<ShapeMotionParams> motions` (exactly 5 entries). Consumed by Task 7.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_shapes_painter.dart';

void main() {
  test('motions has exactly 5 entries', () {
    expect(LiquidShapesPainter.motions, hasLength(5));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/liquid_glow/liquid_shapes_painter_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/liquid_glow/liquid_shapes_painter.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../controller/liquid_glow_controller.dart';
import 'shape_motion.dart';

/// Paints the LiquidGlow floating-shapes shader, packing uniforms in the
/// exact order declared in `shaders/liquid_shapes.frag`.
class LiquidShapesPainter extends CustomPainter {
  LiquidShapesPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.shapePositions,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;

  /// Normalized (0..1) positions of the 5 shapes, in uniform order.
  /// Compute with `computeShapePosition` against [motions].
  final List<Offset> shapePositions;

  static const Color _shapeColor0 = Color(0xFFFFADAD); // triangle
  static const Color _shapeColor1 = Color(0xFFA0E7E5); // roundedSquare
  static const Color _shapeColor2 = Color(0xFFFFD6A5); // circle
  static const double _shapeSize = 0.14;

  /// Fixed per-shape motion config, cycling motion kinds
  /// [orbital, bounce, travel, orbital, bounce] with distinct
  /// centers/phases so shapes don't overlap in timing.
  static const List<ShapeMotionParams> motions = [
    ShapeMotionParams.orbital(
      center: Offset(0.35, 0.4), radius: 0.18, speed: 1.0, phase: 0),
    ShapeMotionParams.bounce(
      center: Offset(0.65, 0.5), radius: 0.15, speed: 1.0, phase: 1.5),
    ShapeMotionParams.travel(
      pointA: Offset(0.85, 0.15), pointB: Offset(0.5, 0.75),
      speed: 1.0, phase: 3.0),
    ShapeMotionParams.orbital(
      center: Offset(0.6, 0.7), radius: 0.12, speed: 1.0, phase: 2.4),
    ShapeMotionParams.bounce(
      center: Offset(0.25, 0.65), radius: 0.1, speed: 1.0, phase: 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, _shapeColor0.red / 255)
      ..setFloat(i++, _shapeColor0.green / 255)
      ..setFloat(i++, _shapeColor0.blue / 255)
      ..setFloat(i++, _shapeColor0.alpha / 255)
      ..setFloat(i++, _shapeColor1.red / 255)
      ..setFloat(i++, _shapeColor1.green / 255)
      ..setFloat(i++, _shapeColor1.blue / 255)
      ..setFloat(i++, _shapeColor1.alpha / 255)
      ..setFloat(i++, _shapeColor2.red / 255)
      ..setFloat(i++, _shapeColor2.green / 255)
      ..setFloat(i++, _shapeColor2.blue / 255)
      ..setFloat(i++, _shapeColor2.alpha / 255);

    for (final pos in shapePositions) {
      shader
        ..setFloat(i++, pos.dx)
        ..setFloat(i++, pos.dy);
    }

    shader.setFloat(i++, _shapeSize);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidShapesPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.shapePositions != shapePositions ||
        oldDelegate.controller != controller;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/liquid_glow/liquid_shapes_painter_test.dart`
Expected: PASS (1 test)

- [ ] **Step 5: Commit**

```bash
git add lib/src/liquid_glow/liquid_shapes_painter.dart test/liquid_glow/liquid_shapes_painter_test.dart
git commit -m "feat: add LiquidShapesPainter"
```

---

## Task 7: Wire dispatch into `_LiquidGlowState`

**Files:**
- Modify: `lib/src/liquid_glow/liquid_glow_widget.dart`
- Modify: `test/widget/liquid_glow_lifecycle_test.dart`

**Interfaces:**
- Consumes: `LiquidGlowPresetKind` (Task 2), `ShaderWarmCache.liquidOrbs`/`.liquidShapes` (Tasks 3, 5), `LiquidOrbsPainter`/`LiquidOrbsPainter.motions` (Task 4), `LiquidShapesPainter`/`LiquidShapesPainter.motions` (Task 6), `computeShapePosition` (Task 1).
- Produces: `LiquidGlow` now renders the correct painter for any `LiquidGlowPreset`, chosen once at `initState` based on `widget.controller.preset.kind`.

- [ ] **Step 1: Write the failing tests**

Add to `test/widget/liquid_glow_lifecycle_test.dart` (the file already has `setUp(ShaderWarmCache.debugClearForTesting)` at the top and the scoped `_liquidGlowCustomPaint` finder — reuse both, don't redefine):

```dart
  testWidgets('darkGlow preset renders with LiquidOrbsPainter',
      (tester) async {
    final controller = LiquidGlowController(
      preset: const LiquidGlowPreset.darkGlow(
        backgroundColor: Color(0xFF0B0F1A),
      ),
    );
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    expect(tester.takeException(), isNull);
    final painter =
        tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter;
    expect(painter, isA<LiquidOrbsPainter>());
  });

  testWidgets('floatingShapes preset renders with LiquidShapesPainter',
      (tester) async {
    final controller = LiquidGlowController(
      preset: const LiquidGlowPreset.floatingShapes(),
    );
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    expect(tester.takeException(), isNull);
    final painter =
        tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter;
    expect(painter, isA<LiquidShapesPainter>());
  });

  testWidgets('darkGlow preset freezes time when reduce motion is on',
      (tester) async {
    final controller = LiquidGlowController(
      preset: const LiquidGlowPreset.darkGlow(
        backgroundColor: Color(0xFF0B0F1A),
      ),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: MaterialApp(
          navigatorObservers: [liquidGlowRouteObserver],
          home: LiquidGlow(controller: controller),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final before =
        (tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter
                as LiquidOrbsPainter)
            .timeSeconds;
    await tester.pump(const Duration(milliseconds: 100));
    final after =
        (tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter
                as LiquidOrbsPainter)
            .timeSeconds;
    expect(after, before);
  });
```

Add the two new imports this file needs at the top (alongside the existing `liquid_glow_painter.dart` import):

```dart
import 'package:liquid_glow/src/liquid_glow/liquid_orbs_painter.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_shapes_painter.dart';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/liquid_glow_lifecycle_test.dart`
Expected: FAIL — `LiquidGlowPreset.darkGlow`/`.floatingShapes` compile fine (Task 2 already landed), but the painter is always `LiquidGlowPainter` regardless of preset kind, so the `isA<LiquidOrbsPainter>()`/`isA<LiquidShapesPainter>()` assertions fail

- [ ] **Step 3: Modify `_LiquidGlowState` to dispatch by `preset.kind`**

In `lib/src/liquid_glow/liquid_glow_widget.dart`, add imports:

```dart
import 'liquid_glow_preset.dart';
import 'liquid_orbs_painter.dart';
import 'liquid_shapes_painter.dart';
import 'shape_motion.dart';
```

Change the shader-loading line in `initState` from:

```dart
    ShaderWarmCache.load(ShaderWarmCache.liquidFluid).then((program) {
      if (mounted) setState(() => _program = program);
    });
```

to:

```dart
    ShaderWarmCache.load(_shaderAssetKeyFor(widget.controller.preset.kind))
        .then((program) {
      if (mounted) setState(() => _program = program);
    });
```

Add this private helper method to `_LiquidGlowState` (near `_handlePointer`):

```dart
  String _shaderAssetKeyFor(LiquidGlowPresetKind kind) {
    switch (kind) {
      case LiquidGlowPresetKind.noise:
        return ShaderWarmCache.liquidFluid;
      case LiquidGlowPresetKind.darkOrbs:
        return ShaderWarmCache.liquidOrbs;
      case LiquidGlowPresetKind.floatingShapes:
        return ShaderWarmCache.liquidShapes;
    }
  }

  CustomPainter _buildPainter(ui.FragmentProgram program) {
    switch (widget.controller.preset.kind) {
      case LiquidGlowPresetKind.noise:
        return LiquidGlowPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          touch: _touch,
        );
      case LiquidGlowPresetKind.darkOrbs:
        return LiquidOrbsPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          orbPositions: [
            for (final motion in LiquidOrbsPainter.motions)
              computeShapePosition(
                  motion, _elapsedSeconds, widget.controller.speed),
          ],
        );
      case LiquidGlowPresetKind.floatingShapes:
        return LiquidShapesPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          shapePositions: [
            for (final motion in LiquidShapesPainter.motions)
              computeShapePosition(
                  motion, _elapsedSeconds, widget.controller.speed),
          ],
        );
    }
  }
```

Change the painter construction inside `build()`'s `LayoutBuilder` from:

```dart
              return CustomPaint(
                size: size,
                painter: LiquidGlowPainter(
                  program: program,
                  timeSeconds: _elapsedSeconds,
                  controller: widget.controller,
                  touch: _touch,
                ),
              );
```

to:

```dart
              return CustomPaint(
                size: size,
                painter: _buildPainter(program),
              );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/widget/liquid_glow_lifecycle_test.dart`
Expected: PASS (all cases in the file, including the 3 new ones)

- [ ] **Step 5: Run the full suite**

Run: `flutter test`
Expected: PASS (every test in the project)

- [ ] **Step 6: Commit**

```bash
git add lib/src/liquid_glow/liquid_glow_widget.dart test/widget/liquid_glow_lifecycle_test.dart
git commit -m "feat: dispatch LiquidGlow shader/painter by preset kind"
```

---

## Task 8: Documentation

**Files:**
- Modify: `README.md`
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: pub.dev-facing documentation covering the two new presets, referencing the real API from Tasks 2-7.

- [ ] **Step 1: Add a section to `README.md`**

Insert after the existing "Presets: `LiquidGlowPreset.aurora()`, `.lavaLamp()`, `.cyberpunk()`, or `.custom(...)`." line:

```markdown

Two more presets render discrete merging shapes instead of a noise
gradient:

```dart
LiquidGlowController(
  preset: const LiquidGlowPreset.darkGlow(
    backgroundColor: Color(0xFF0B0F1A),
  ),
);
LiquidGlowController(preset: const LiquidGlowPreset.floatingShapes());
```

`darkGlow` floats 3 glowing orbs over a background color you choose.
`floatingShapes` floats 5 shapes (triangles, rounded squares, circles)
that merge into each other like liquid, over a solid white background.
Both use the same `LiquidGlowController`/`LiquidGlow` API as every other
preset — `speed`/`intensity` still apply, and both still respect
`enableTouchReaction`'s absence of effect (touch reaction is only
implemented for the noise-based presets).
```

- [ ] **Step 2: Update `CHANGELOG.md`**

Add a new entry above the existing `## 0.1.0` entry:

```markdown
## 0.2.0

* Added `LiquidGlowPreset.darkGlow({required backgroundColor})`: 3 glowing
  orbs (orbiting, bouncing, and traveling corner-to-center) merging via
  GLSL SDF blending over a developer-chosen dark background.
* Added `LiquidGlowPreset.floatingShapes()`: 5 shapes (triangles, rounded
  squares, circles) merging into a liquid-like composition over a solid
  white background.
```

Also bump the `version:` field in `pubspec.yaml` from `0.1.0` to `0.2.0`.

- [ ] **Step 3: Verify analysis still passes**

Run: `flutter analyze`
Expected: same 8 pre-existing `deprecated_member_use` infos as before this plan (from `Color.red`/`.green`/`.blue`/`.alpha` in the two pre-existing painters) — no new issues from `README.md`/`CHANGELOG.md`/`pubspec.yaml` changes (these aren't analyzed).

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md pubspec.yaml
git commit -m "docs: document darkGlow and floatingShapes presets, bump to 0.2.0"
```

---

## Task 9: Example app + manual verification

**Files:**
- Modify: `example/lib/main.dart`

**Interfaces:**
- Consumes: `LiquidGlowPreset.darkGlow`/`.floatingShapes` (Task 2), full dispatch (Task 7).
- Produces: a way to see both new presets running in the example app, and a completed manual on-device verification pass.

- [ ] **Step 1: Add a background-style selector to `example/lib/main.dart`**

The existing `_DemoPageState` holds one `LiquidGlowController` (`_controller`) constructed once in `initState` and reused across the Aurora/Lava Lamp/Cyberpunk `SegmentedButton` via `animateToColors`. That morph-based switch only works between noise presets that share a shader — `darkGlow`/`floatingShapes` use different shaders entirely, so switching to them requires constructing a **new** controller (disposing the old one) rather than morphing the existing one.

Add a `_BackgroundStyle` enum and a second top-level selector above the existing preset `SegmentedButton`, so the two switching mechanisms stay independent and the existing noise-preset morph demo is untouched:

```dart
enum _BackgroundStyle { fluidGradient, darkGlow, floatingShapes }
```

Add a field `_BackgroundStyle _backgroundStyle = _BackgroundStyle.fluidGradient;` to `_DemoPageState`, alongside the existing `_controller` field, and change `_controller`'s declaration from `late final LiquidGlowController _controller;` to `late LiquidGlowController _controller;` (drop `final` — it now gets reassigned when the background style changes).

Add this method to `_DemoPageState`:

```dart
  void _selectBackgroundStyle(_BackgroundStyle style) {
    if (style == _backgroundStyle) return;
    final oldController = _controller;
    setState(() {
      _backgroundStyle = style;
      _controller = switch (style) {
        _BackgroundStyle.fluidGradient =>
          LiquidGlowController(preset: _presets[_presetIndex]),
        _BackgroundStyle.darkGlow => LiquidGlowController(
            preset: const LiquidGlowPreset.darkGlow(
              backgroundColor: Color(0xFF0B0F1A),
            ),
          ),
        _BackgroundStyle.floatingShapes =>
          LiquidGlowController(preset: const LiquidGlowPreset.floatingShapes()),
      };
    });
    oldController.dispose();
  }
```

In `build()`, insert a new `SegmentedButton<_BackgroundStyle>` immediately above the existing preset `SegmentedButton<int>` (inside the same `Column`, before the `'liquid_glow'` title or right after it — place it right after the title `Text` and before the existing preset segmented button):

```dart
                  SegmentedButton<_BackgroundStyle>(
                    segments: const [
                      ButtonSegment(
                        value: _BackgroundStyle.fluidGradient,
                        label: Text('Fluid')),
                      ButtonSegment(
                        value: _BackgroundStyle.darkGlow,
                        label: Text('Dark Glow')),
                      ButtonSegment(
                        value: _BackgroundStyle.floatingShapes,
                        label: Text('Shapes')),
                    ],
                    selected: {_backgroundStyle},
                    onSelectionChanged: (selection) =>
                        _selectBackgroundStyle(selection.first),
                  ),
                  const SizedBox(height: 16),
```

The rest of the UI (preset segmented button, sliders, morph button, Siri glow controls) stays visible and functional regardless of `_backgroundStyle` — when `darkGlow`/`floatingShapes` is selected, the Aurora/Lava Lamp/Cyberpunk buttons and "Morph colors" button simply have no visible effect (they act on `_presets`/`animateToColors`, which only matters for the `fluidGradient` style), which is acceptable for this example and avoids restructuring the whole screen.

- [ ] **Step 2: Fetch dependencies and analyze**

Run: `cd example && flutter pub get && flutter analyze`
Expected: `Got dependencies!` then `No issues found!`

- [ ] **Step 3: Manually verify on a real simulator/device (required)**

Run: `flutter run` (from `example/`, on an iOS simulator or Android emulator/device — reuse whichever was used in the prior session)

Verify by hand:
- Selecting "Dark Glow" shows a solid dark background with 3 colored glow orbs floating — confirm their motions are visibly *different from each other* (one circles, one bounces vertically, one drifts between two points and back), not all doing the same thing.
- Selecting "Shapes" shows a solid white background with 5 shapes (triangles/rounded squares/circles) floating and visibly merging into each other (soft, blobby edges) where they get close, not just overlapping with hard edges.
- Both new styles respond to the Speed and Intensity sliders (motion/size visibly changes).
- Switching between "Fluid" / "Dark Glow" / "Shapes" and back does not crash, hang, or show a blank screen at any point (this exact category of failure — a real crash despite a fully green test suite — is what the prior session's live verification caught twice; do not skip this step even though `flutter analyze`/`flutter test` are clean).
- With the OS "Reduce Motion" accessibility setting enabled, both new styles freeze on a static frame like every other preset.

If anything fails here, treat it as a real bug: fix it, add or extend a regression test the way the prior session did (see `docs/superpowers/sdd_notes` — actually, see this package's own git history around commits `bc4adb3` and `a84b5e5` for the pattern: diagnose via screenshots/sequential frames if needed, fix the root cause, write a regression test that would have caught it, re-verify on-device, then commit).

- [ ] **Step 4: Commit**

```bash
git add example/lib/main.dart
git commit -m "feat: add darkGlow/floatingShapes selector to example app"
```

---

## Final Verification

- [ ] Run `flutter test` from the package root: PASS, 0 failures.
- [ ] Run `flutter analyze` from both the package root and `example/`: no new issues beyond the 8 pre-existing `deprecated_member_use` infos.
- [ ] Confirm the on-device manual verification in Task 9 Step 3 was actually performed and passed (not skipped).
- [ ] Confirm `git log --oneline` shows one commit per task, in order.
