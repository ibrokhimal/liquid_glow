# liquid_glow — Design Spec

Date: 2026-07-14
Status: Approved

## Summary

`liquid_glow` is a Flutter package for `pub.dev` providing high-performance,
shader-driven fluid/gradient background animations (`LiquidGlow`) and an
independent iOS 18-style Siri screen-edge glow effect (`SiriGlowEdge`). It is
positioned as a modern, GPU-shader-based alternative to `fluid_background`.

## Goals

- 60/120 FPS fluid background and edge-glow animations via Flutter Fragment
  Shaders (GLSL, `FragmentProgram`), not CPU-bound `CustomPainter` math.
- A reactive, declarative Dart API (`LiquidGlowController` +
  `ChangeNotifier`) that lets developers drive animations programmatically:
  play/pause/stop, live speed/intensity/origin tuning, smooth color morphing,
  and binding an external `Stream<double>` (e.g. audio levels) to intensity.
- Automatic resource management: animations pause when the app is
  backgrounded, when the widget's `TickerMode` is disabled, or when OS-level
  "Reduce Motion" is on — without the consumer having to wire this up.
- `SiriGlowEdge` ships as a fully independent widget — usable standalone or
  stacked over `LiquidGlow` — with state-driven modes (`idle`, `listening`,
  `thinking`, `speaking`), configurable edge masking, and full color/timing
  customization.

## Non-Goals (v1)

- Web and desktop platform support. Fragment-shader behavior on
  Skwasm/CanvasKit and desktop Impeller is less mature; v1 targets iOS +
  Android only, where Impeller is stable.
- Golden/visual-regression tests for shader output (flaky across GPU/driver
  differences in CI). Visual correctness is verified manually via the
  example app.
- Any built-in audio-capture/microphone code. `bindIntensityStream` accepts
  a generic `Stream<double>`; callers wire their own audio/sensor package.
- True physical fluid simulation (flow-field advection). Domain-warped
  noise gives a convincing, cheap "liquid" look without simulation cost.

## Platform & SDK Constraints

- Flutter ≥ 3.19, Dart ≥ 3.3.
- iOS + Android only for v1. Impeller renderer assumed enabled (default on
  supported Flutter versions for these platforms).
- License: MIT.

## Architecture

### Shared core (`lib/src/core/`)

- **`GlowTicker`** — wraps a single `Ticker`, gated by four independent
  "should animate" signals ANDed together:
  1. `AppLifecycleListener` — paused when app is backgrounded.
  2. `TickerMode.of(context)` — paused when offscreen (e.g. `Offstage`,
     hidden tab).
  3. `RouteAware` — paused when the widget's route is covered/pushed behind
     another route (e.g. navigated away to a new screen).
  4. `ReduceMotion` (below) — paused when OS reduce-motion is on.
  A controller's explicit `pause()` (for `LiquidGlow`) is a fifth,
  user-driven gate layered on top of the other four; it always wins.
- **`ReduceMotion`** — reads `MediaQuery.of(context).disableAnimations`.
  When true, the owning widget renders one static frame (uniforms frozen at
  current values) instead of ticking — never fully blank, never animating.
- **`ColorMorph`** — internal `AnimationController`-driven `ColorTween`
  engine used by `LiquidGlowController.animateToColors`.
- **`ShaderWarmCache`** — loads both `.frag` assets via
  `FragmentProgram.fromAsset` once and shares the loaded programs between
  `LiquidGlow` and `SiriGlowEdge` instances.

### Two independent shader modules

1. **`shaders/liquid_fluid.frag`** (LiquidGlow core)
   - Algorithm: 3-4 octaves of domain-warped simplex noise, blended across a
     uniform color-ramp array (up to 6 colors), producing a "mesh gradient"
     look. Chosen over metaballs (higher per-pixel SDF cost) and flow-field
     advection (highest complexity, hardest to hold 120fps) for the best
     performance/visual trade-off, and because it fits the aurora/lava-lamp/
     cyberpunk presets naturally.
   - Touch reaction: a `touch` uniform (`vec2` position, `float` strength,
     `float` age) adds a localized warp bump that decays over ~1.5s —
     implements ripple/attract behavior without extra geometry.
   - Uniforms packed into a single `float[]` buffer per frame (via
     `setFloat`) to minimize Dart↔GPU marshalling calls.

2. **`shaders/siri_edge.frag`** (SiriGlowEdge)
   - Algorithm: per-fragment SDF distance to a rounded-rect border
     (parameterized by `borderWidth`/`borderRadius`), driving glow falloff.
     A `state` uniform selects among idle/listening/thinking/speaking
     animation curves within the same shader (cheaper than shader-swapping).
   - Per-edge masking (`GlowEdgeMask`) is applied as a uniform bitmask that
     zeroes out contribution from masked-off edges.

## Package Structure

```
liquid_glow/
  pubspec.yaml                # MIT license, Flutter >=3.19, Dart >=3.3
  CHANGELOG.md
  LICENSE
  README.md
  shaders/
    liquid_fluid.frag
    siri_edge.frag
  lib/
    liquid_glow.dart          # public export barrel
    src/
      core/
        glow_ticker.dart
        reduce_motion.dart
        color_morph.dart
        shader_warm_cache.dart
      controller/
        liquid_glow_controller.dart
        liquid_glow_state.dart
      liquid_glow/
        liquid_glow_widget.dart
        liquid_glow_painter.dart
        liquid_glow_preset.dart
        touch_reaction.dart
      siri_glow/
        siri_glow_edge.dart
        siri_glow_state.dart
        glow_edge_mask.dart
  test/
    controller/liquid_glow_controller_test.dart
    widget/liquid_glow_lifecycle_test.dart
    widget/reduce_motion_test.dart
    widget/siri_glow_state_test.dart
  example/
    lib/main.dart
```

## Public API

### `LiquidGlowController extends ChangeNotifier`

```dart
class LiquidGlowController extends ChangeNotifier {
  LiquidGlowController({
    LiquidGlowPreset preset = const LiquidGlowPreset.aurora(),
    double speed = 1.0,
    double intensity = 1.0,
    AlignmentGeometry origin = Alignment.center,
  });

  // Playback
  void play();
  void pause();
  void stop();               // pause + reset time uniform to 0

  // Color morphing
  Future<void> animateToColors(
    List<Color> newColors, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOut,
  });

  // Live-tunable properties (each setter calls notifyListeners)
  double speed;
  double intensity;
  AlignmentGeometry origin;
  Offset? touchOverride;      // programmatic touch-reaction target

  // External reactive binding (audio levels, sensor data, etc.)
  void bindIntensityStream(
    Stream<double> stream, {
    double Function(double raw)? mapper,
  });
  void unbindIntensityStream();

  bool get isPlaying;
  LiquidGlowPreset get preset;

  @override
  void dispose();            // cancels stream subscription, stops ticker
}
```

`bindIntensityStream` subscribes internally; each event updates `intensity`
(through `mapper` if given) and calls `notifyListeners()`.
`animateToColors` drives its own `ColorMorph`, calling `notifyListeners()`
each frame until done; the returned `Future` resolves on completion.

### `LiquidGlowPreset`

```dart
class LiquidGlowPreset {
  const LiquidGlowPreset.aurora();     // green/purple/blue, slow
  const LiquidGlowPreset.lavaLamp();   // warm reds/oranges, dense & slow
  const LiquidGlowPreset.cyberpunk();  // neon pink/cyan, fast & aggressive
  const LiquidGlowPreset.custom({
    required List<Color> colors,
    required double baseSpeed,
    required double noiseScale,
  });
}
```

### `LiquidGlow` widget

```dart
class LiquidGlow extends StatefulWidget {
  const LiquidGlow({
    required this.controller,
    this.enableTouchReaction = false,
    this.child,
    super.key,
  });

  final LiquidGlowController controller;
  final bool enableTouchReaction;
  final Widget? child;
}
```

Structure: `RepaintBoundary` → optional `GestureDetector` (only attached
when `enableTouchReaction`) → shader-backed painter listening to
`controller` via `AnimatedBuilder` → gated by `GlowTicker`/`ReduceMotion`.

### `SiriGlowEdge` widget (independent of `LiquidGlowController`)

```dart
enum SiriGlowState { idle, listening, thinking, speaking }

class GlowEdgeMask {
  const GlowEdgeMask({
    this.top = true, this.bottom = true,
    this.left = true, this.right = true,
  });
  static const all = GlowEdgeMask();
  static const top = GlowEdgeMask(bottom: false, left: false, right: false);
  // .bottom / .left / .right similarly; combine via copyWith
}

class SiriGlowEdge extends StatefulWidget {
  const SiriGlowEdge({
    required this.state,
    this.colors = const [Color(0xFF7F5AF0), Color(0xFF2CB1E0), Color(0xFFE0526B)],
    this.borderRadius = const BorderRadius.all(Radius.circular(48)),
    this.borderWidth = 6.0,
    this.blurRadius = 24.0,
    this.mask = GlowEdgeMask.all,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.child,
    super.key,
  });

  final SiriGlowState state;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double blurRadius;
  final GlowEdgeMask mask;
  final Duration transitionDuration;
  final Widget? child;
}
```

Changing `state` cross-fades shader uniforms over `transitionDuration` via
an internal `AnimationController` (not exposed — this widget is driven
declaratively via its `state` property, unlike the controller-driven
`LiquidGlow`). Each `SiriGlowState` maps to a preset animation curve baked
into `siri_edge.frag`: idle = gentle slow rotation, listening = pulsation,
thinking = fast color cycling, speaking = high-intensity wave patterns.
Can be used standalone (wraps any `child`) or stacked over `LiquidGlow` via
a plain `Stack` — no coupling between the two widgets.

## Accessibility & Lifecycle Behavior

Applies identically to both `LiquidGlow` and `SiriGlowEdge`:

- OS "Reduce Motion" → static single frame, uniforms frozen, no ticking.
- App backgrounded → ticking paused via `AppLifecycleListener`.
- Widget offscreen (`TickerMode` disabled, e.g. hidden tab) → ticking
  paused.
- Route covered/navigated away from → ticking paused via `RouteAware`.
- `LiquidGlowController.pause()` is an explicit, user-driven override on
  top of the above for `LiquidGlow`; `SiriGlowEdge` has no external
  controller so only the four automatic gates apply to it.

## Testing Plan

- **Unit** (`liquid_glow_controller_test.dart`): play/pause/stop
  transitions; `animateToColors` reaches target colors and resolves its
  `Future`; `bindIntensityStream`/`unbindIntensityStream` forward mapped
  values correctly and clean up subscriptions on `dispose()`.
- **Widget** (`liquid_glow_lifecycle_test.dart`): app-lifecycle changes and
  `TickerMode(enabled: false)` around a `LiquidGlow` pause/resume ticking.
- **Widget** (`reduce_motion_test.dart`): with
  `MediaQuery(disableAnimations: true)`, confirm no repeated frame
  scheduling for both `LiquidGlow` and `SiriGlowEdge`.
- **Widget** (`siri_glow_state_test.dart`): changing `state` triggers the
  cross-fade transition and settles into the new state's params after
  `transitionDuration`.
- No golden/visual-regression tests for shader output in v1 (see
  Non-Goals); visual correctness verified manually via the example app.

## Example App

Single scrollable demo screen (`example/lib/main.dart`):

- Full-bleed `LiquidGlow` background with a preset switcher
  (`SegmentedButton`: Aurora / Lava Lamp / Cyberpunk), sliders for speed and
  intensity wired to the controller, and touch-reaction enabled so dragging
  visibly warps the fluid.
- "Morph colors" button calling `controller.animateToColors([...])` with a
  random palette.
- `SiriGlowEdge` stacked over the same background via `Stack`, with four
  buttons (Idle / Listening / Thinking / Speaking) flipping its `state`,
  plus a mask toggle row demoing `.top`/`.bottom`/`.all` live.

## Key Decisions Log

| Decision | Choice | Reason |
|---|---|---|
| Platform scope | iOS + Android only | Impeller maturity; avoids web/desktop shader fallback complexity |
| Controller pattern | `ChangeNotifier` | Zero extra deps, idiomatic Flutter, familiar API shape |
| Fluid algorithm | Domain-warped simplex noise | Best perf/visual trade-off; fits presets naturally |
| Siri glow render | Dedicated `.frag` shader | Consistent with shader-first principle, cheap at 120fps |
| Testing depth | Unit + widget, no goldens | Golden shader tests are CI-flaky across GPU/driver differences |
| Visibility detection | `TickerMode` + `RouteAware` only | Avoids third-party dependency; true scroll-offscreen is a narrower case consumers can handle themselves |
| Package location | New `liquid_glow/` subfolder under `PACAGES` | `PACAGES` treated as a multi-package workspace |
| License | MIT | Standard for pub.dev packages, maximizes adoption |
