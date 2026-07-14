# liquid_glow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `liquid_glow` Flutter package — a shader-driven fluid glow background (`LiquidGlow`) and an independent iOS 18-style Siri edge-glow effect (`SiriGlowEdge`), both reactive, accessible, and resource-managed.

**Architecture:** Two `FragmentProgram`-backed `CustomPainter` widgets share a common core (`GlowTickerMixin` for lifecycle/visibility/reduce-motion gating, `ShaderWarmCache` for shader loading, `ColorMorph` for tweening). `LiquidGlow` is driven externally by a `ChangeNotifier`-based `LiquidGlowController`; `SiriGlowEdge` is driven declaratively via its `state` property with its own internal cross-fade.

**Tech Stack:** Flutter SDK only (no third-party runtime dependencies), Dart `dart:ui` `FragmentProgram`/`FragmentShader`, GLSL fragment shaders compiled via Flutter's shader tooling, `flutter_test` for unit/widget tests, `flutter_lints` for static analysis.

## Global Constraints

- Flutter >= 3.19.0, Dart >= 3.3.0 (from spec's Platform & SDK Constraints).
- iOS + Android only for v1 — do not add web/desktop-specific fallback code.
- MIT license.
- No third-party runtime dependencies (only `flutter`/`flutter_test`/`flutter_lints`) — spec's "Non-Goals" and decision log both reject adding deps (e.g. `visibility_detector`) to keep the footprint minimal.
- No golden/visual-regression tests for shader output — verify visuals manually via the example app (spec Non-Goals + Testing Plan).
- `bindIntensityStream` takes a generic `Stream<double>` — no audio-capture code ships in the package.
- Every public widget/controller must respect: OS Reduce Motion (static frame, no ticking), app backgrounded (paused), route covered (paused), `TickerMode` disabled (paused).
- Package root: `/Users/ibrokhimal/PROJECTS/PACAGES/liquid_glow/` (git repo already initialized, spec committed at `docs/superpowers/specs/2026-07-14-liquid-glow-design.md`).

**Implementation notes vs. spec sketch** (spec's code blocks were illustrative, not locked signatures; these are corrections/refinements made during planning):
- The spec's `GlowEdgeMask` sketch had named boolean fields (`top`, `bottom`, `left`, `right`) *and* static presets of the same names (`GlowEdgeMask.top`) — a Dart compile error, since a static member cannot share a name with an instance member. Task 10 resolves it with `enum GlowEdge { top, right, bottom, left }` plus `GlowEdgeMask(Set<GlowEdge>)`, preserving the same call-site ergonomics (`GlowEdgeMask.all`, `GlowEdgeMask.top`, combinable via `|`).
- The spec's package tree listed `lib/src/controller/liquid_glow_state.dart` as an "immutable snapshot" alongside the controller. No task in this plan creates it: `LiquidGlowController` (Task 7) exposes its fields directly, and no part of the spec's Public API section references a separate state type — adding one would be an unused abstraction (YAGNI).
- The spec described `GlowTicker` as a class that "wraps a single Ticker." Task 3 implements it as `GlowTickerMixin<T>`, a `State` mixin, instead — this is what makes it directly testable via the widget-level tests the spec's own Testing Plan calls for (`liquid_glow_lifecycle_test.dart`, `reduce_motion_test.dart`), rather than needing a separate mock `TickerProvider` harness. The conceptual contract (gate one ticker behind four visibility/motion signals) is unchanged.

---

## Task 1: Package Scaffolding

**Files:**
- Create: `pubspec.yaml`
- Create: `analysis_options.yaml`
- Create: `LICENSE`
- Create: `.gitignore`
- Create: `CHANGELOG.md`
- Create: `lib/liquid_glow.dart`

**Interfaces:**
- Produces: an empty-but-valid `liquid_glow` package that `flutter pub get` and `flutter analyze` succeed against. Later tasks add exports to `lib/liquid_glow.dart` and add a `flutter: shaders:` section to `pubspec.yaml` once shader files exist (Tasks 8 and 11).

- [ ] **Step 1: Create `pubspec.yaml`**

```yaml
name: liquid_glow
description: >
  High-performance, shader-driven fluid glow backgrounds and an iOS
  18-style Siri screen-edge glow effect for Flutter, powered by Impeller
  fragment shaders.
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0
```

- [ ] **Step 2: Create `analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_single_quotes: true
```

- [ ] **Step 3: Create `LICENSE`**

```
MIT License

Copyright (c) 2026 liquid_glow contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

- [ ] **Step 4: Create `.gitignore`**

```
.dart_tool/
.packages
build/
pubspec.lock
.flutter-plugins
.flutter-plugins-dependencies
*.iml
.idea/
```

- [ ] **Step 5: Create `CHANGELOG.md`**

```markdown
## 0.1.0

* Initial development release.
```

- [ ] **Step 6: Create `lib/liquid_glow.dart`**

```dart
/// Shader-driven fluid glow backgrounds and an iOS 18-style Siri
/// screen-edge glow effect for Flutter.
library liquid_glow;
```

- [ ] **Step 7: Fetch packages and verify analysis passes**

Run: `cd /Users/ibrokhimal/PROJECTS/PACAGES/liquid_glow && flutter pub get`
Expected: `Got dependencies!`

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml analysis_options.yaml LICENSE .gitignore CHANGELOG.md lib/liquid_glow.dart
git commit -m "chore: scaffold liquid_glow package"
```

---

## Task 2: Core — `ReduceMotion`

**Files:**
- Create: `lib/src/core/reduce_motion.dart`
- Test: `test/core/reduce_motion_test.dart`

**Interfaces:**
- Produces: `ReduceMotion.of(BuildContext context) -> bool`, used by `GlowTickerMixin` (Task 3) and both painters.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/reduce_motion.dart';

void main() {
  testWidgets('ReduceMotion.of reflects MediaQuery.disableAnimations',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (context) {
            capturedContext = context;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(ReduceMotion.of(capturedContext), isTrue);
  });

  testWidgets('ReduceMotion.of defaults to false without MediaQuery',
      (tester) async {
    late BuildContext capturedContext;

    await tester.pumpWidget(
      Builder(
        builder: (context) {
          capturedContext = context;
          return const SizedBox();
        },
      ),
    );

    expect(ReduceMotion.of(capturedContext), isFalse);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/reduce_motion_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/core/reduce_motion.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/widgets.dart';

/// Reads the OS-level "Reduce Motion" accessibility setting.
///
/// Widgets in this package use this instead of ticking when the user has
/// requested reduced motion, freezing on a single static frame.
class ReduceMotion {
  const ReduceMotion._();

  static bool of(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/reduce_motion_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/core/reduce_motion.dart test/core/reduce_motion_test.dart
git commit -m "feat: add ReduceMotion accessibility helper"
```

---

## Task 3: Core — `GlowTickerMixin` and route observer

**Files:**
- Create: `lib/src/core/glow_ticker.dart`
- Test: `test/core/glow_ticker_test.dart`

**Interfaces:**
- Consumes: `ReduceMotion.of` (Task 2).
- Produces:
  - `final RouteObserver<ModalRoute<void>> liquidGlowRouteObserver` — top-level singleton consumers add to `MaterialApp.navigatorObservers`.
  - `mixin GlowTickerMixin<T extends StatefulWidget> on State<T> implements TickerProvider, RouteAware` with:
    - `abstract void onGlowTick(Duration elapsed)` — implementers override this.
    - `RouteObserver<ModalRoute<void>>? get routeObserver` — override to return `liquidGlowRouteObserver` (defaults to `null`, meaning no route-aware pausing).
    - `bool get shouldAnimate` — true only when app visible, route visible, `TickerMode.of(context)` true, and reduce-motion off.
  - Used by `LiquidGlow` (Task 9) and `SiriGlowEdge` (Task 12) via `with SingleTickerProviderStateMixin, GlowTickerMixin<TheWidget>`.

- [ ] **Step 1: Write the failing test**

This test uses a minimal `StatefulWidget` built on top of `GlowTickerMixin` to verify the four pause/resume gates without needing the real `LiquidGlow`/`SiriGlowEdge` widgets (those get their own lifecycle tests in Tasks 9 and 12).

```dart
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/glow_ticker.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with SingleTickerProviderStateMixin, GlowTickerMixin<_Probe> {
  int tickCount = 0;

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void onGlowTick(Duration elapsed) {
    tickCount++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

_ProbeState _stateOf(WidgetTester tester) =>
    tester.state<_ProbeState>(find.byType(_Probe));

void main() {
  testWidgets('ticks while visible and stops when TickerMode is disabled',
      (tester) async {
    await tester.pumpWidget(const _Probe());
    await tester.pump(const Duration(milliseconds: 16));
    final afterVisible = _stateOf(tester).tickCount;
    expect(afterVisible, greaterThan(0));

    await tester.pumpWidget(
      const TickerMode(enabled: false, child: _Probe()),
    );
    final countAtDisable = _stateOf(tester).tickCount;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_stateOf(tester).tickCount, countAtDisable);
  });

  testWidgets('stops ticking when reduce motion is enabled', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: _Probe(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_stateOf(tester).tickCount, 0);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/glow_ticker_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/core/glow_ticker.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'reduce_motion.dart';

/// Shared route observer. Add this to `MaterialApp.navigatorObservers` (or
/// `WidgetsApp.navigatorObservers`) so [GlowTickerMixin] can pause ticking
/// when a [LiquidGlow] or [SiriGlowEdge] is covered by a pushed route.
///
/// This is optional — without it, ticking still pauses correctly on app
/// background and `TickerMode`/reduce-motion, just not on route coverage.
final RouteObserver<ModalRoute<void>> liquidGlowRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Gates a single [Ticker] behind app lifecycle, [TickerMode], route
/// visibility, and OS reduce-motion state, so glow widgets automatically
/// pause when backgrounded, offscreen, covered, or when the user has
/// requested reduced motion.
mixin GlowTickerMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider, RouteAware {
  Ticker? _glowTicker;
  AppLifecycleListener? _lifecycleListener;
  bool _appVisible = true;
  bool _routeVisible = true;
  ModalRoute<void>? _subscribedRoute;

  /// Override to return [liquidGlowRouteObserver] to enable route-aware
  /// pausing. Defaults to `null` (route coverage is ignored).
  RouteObserver<ModalRoute<void>>? get routeObserver => null;

  /// Called once per animation frame while [shouldAnimate] is true.
  void onGlowTick(Duration elapsed);

  /// Whether the ticker should currently be producing frames.
  bool get shouldAnimate =>
      _appVisible &&
      _routeVisible &&
      TickerMode.of(context) &&
      !ReduceMotion.of(context);

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onShow: () => _setAppVisible(true),
      onHide: () => _setAppVisible(false),
      onResume: () => _setAppVisible(true),
      onPause: () => _setAppVisible(false),
    );
    _glowTicker = createTicker(_handleTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = routeObserver;
    final route = ModalRoute.of(context);
    if (observer != null && route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        observer.unsubscribe(this);
      }
      observer.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  void _handleTick(Duration elapsed) {
    if (shouldAnimate) {
      onGlowTick(elapsed);
    }
  }

  void _setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    setState(() => _appVisible = visible);
  }

  @override
  void didPushNext() => setState(() => _routeVisible = false);

  @override
  void didPopNext() => setState(() => _routeVisible = true);

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      routeObserver?.unsubscribe(this);
    }
    _lifecycleListener?.dispose();
    _glowTicker?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/glow_ticker_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/core/glow_ticker.dart test/core/glow_ticker_test.dart
git commit -m "feat: add GlowTickerMixin for lifecycle/visibility/reduce-motion gating"
```

---

## Task 4: Core — `ColorMorph`

**Files:**
- Create: `lib/src/core/color_morph.dart`
- Test: `test/core/color_morph_test.dart`

**Interfaces:**
- Produces: `class ColorMorph` with `Future<void> animate({required List<Color> from, required List<Color> to, required Duration duration, required Curve curve})` and `void dispose()`. Used by `LiquidGlowController.animateToColors` (Task 7).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/color_morph.dart';

void main() {
  testWidgets('animate interpolates and resolves when complete',
      (tester) async {
    final updates = <List<Color>>[];
    final morph = ColorMorph(onUpdate: updates.add);
    addTearDown(morph.dispose);

    var completed = false;
    unawaited(morph
        .animate(
          from: const [Color(0xFF000000)],
          to: const [Color(0xFFFFFFFF)],
          duration: const Duration(milliseconds: 100),
          curve: Curves.linear,
        )
        .then((_) => completed = true));

    // A Ticker's very first delivered frame always reports elapsed ==
    // Duration.zero (its start time baseline is set on that first frame,
    // not at the start() call) — pump once with no duration to consume
    // that baseline frame before asserting on elapsed-time math.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(updates, isNotEmpty);
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 60));
    expect(completed, isTrue);
    expect(updates.last.single, const Color(0xFFFFFFFF));
  });

  testWidgets('animate cycles shorter target list to match source length',
      (tester) async {
    final updates = <List<Color>>[];
    final morph = ColorMorph(onUpdate: updates.add);
    addTearDown(morph.dispose);

    await morph.animate(
      from: const [Color(0xFF000000), Color(0xFF000000)],
      to: const [Color(0xFFFFFFFF)],
      duration: Duration.zero,
      curve: Curves.linear,
    );

    expect(updates.last, hasLength(2));
    expect(updates.last[0], const Color(0xFFFFFFFF));
    expect(updates.last[1], const Color(0xFFFFFFFF));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/color_morph_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/core/color_morph.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

/// Drives a smooth per-channel color-list interpolation over time,
/// independent of any [State]/`vsync` — used by
/// `LiquidGlowController.animateToColors`.
class ColorMorph {
  ColorMorph({required this.onUpdate});

  final ValueChanged<List<Color>> onUpdate;

  Ticker? _ticker;
  Completer<void>? _completer;

  /// Interpolates from [from] to [to] over [duration] using [curve],
  /// calling [onUpdate] on every tick. If [to] has a different length than
  /// [from], its entries are cycled to match.
  Future<void> animate({
    required List<Color> from,
    required List<Color> to,
    required Duration duration,
    required Curve curve,
  }) {
    _ticker?.dispose();
    final matchedTo = _matchLength(from, to);
    final completer = Completer<void>();
    _completer = completer;

    if (duration == Duration.zero) {
      onUpdate(matchedTo);
      completer.complete();
      return completer.future;
    }

    _ticker = Ticker((elapsed) {
      final t =
          (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      final eased = curve.transform(t);
      onUpdate(<Color>[
        for (var i = 0; i < from.length; i++)
          Color.lerp(from[i], matchedTo[i], eased)!,
      ]);
      if (t >= 1.0) {
        _ticker?.stop();
        if (!completer.isCompleted) completer.complete();
      }
    });
    _ticker!.start();
    return completer.future;
  }

  List<Color> _matchLength(List<Color> from, List<Color> to) {
    if (to.length == from.length) return to;
    return List<Color>.generate(from.length, (i) => to[i % to.length]);
  }

  /// Cancels any in-flight animation. Does not complete the pending Future.
  void dispose() {
    _ticker?.dispose();
    _completer = null;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/color_morph_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/core/color_morph.dart test/core/color_morph_test.dart
git commit -m "feat: add ColorMorph color-list interpolation engine"
```

---

## Task 5: Core — `ShaderWarmCache`

**Files:**
- Create: `lib/src/core/shader_warm_cache.dart`
- Test: `test/core/shader_warm_cache_test.dart`

**Interfaces:**
- Produces: `class ShaderWarmCache` with `static Future<ui.FragmentProgram> load(String assetKey, {Future<ui.FragmentProgram> Function(String)? loader})`, `static const String liquidFluid`, `static const String siriEdge`, `static void debugClearForTesting()`. Used by `LiquidGlow` (Task 9) and `SiriGlowEdge` (Task 12); asset-key constants are registered against real files in Tasks 8 and 11.

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

void main() {
  test('load caches the program future per asset key', () {
    ShaderWarmCache.debugClearForTesting();
    var callCount = 0;
    Future<ui.FragmentProgram> fakeLoader(String key) {
      callCount++;
      return Completer<ui.FragmentProgram>().future;
    }

    final first =
        ShaderWarmCache.load('shaders/fake.frag', loader: fakeLoader);
    final second =
        ShaderWarmCache.load('shaders/fake.frag', loader: fakeLoader);

    expect(identical(first, second), isTrue);
    expect(callCount, 1);
  });

  test('load uses a distinct cache entry per asset key', () {
    ShaderWarmCache.debugClearForTesting();
    var callCount = 0;
    Future<ui.FragmentProgram> fakeLoader(String key) {
      callCount++;
      return Completer<ui.FragmentProgram>().future;
    }

    ShaderWarmCache.load('shaders/a.frag', loader: fakeLoader);
    ShaderWarmCache.load('shaders/b.frag', loader: fakeLoader);

    expect(callCount, 2);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/shader_warm_cache_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/core/shader_warm_cache.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:ui' as ui;

/// Loads and caches [ui.FragmentProgram]s so [LiquidGlow] and
/// [SiriGlowEdge] instances share one compiled shader each instead of each
/// widget instance re-loading its own.
class ShaderWarmCache {
  ShaderWarmCache._();

  static final Map<String, Future<ui.FragmentProgram>> _programs = {};

  /// Asset key for the LiquidGlow fluid shader (registered in `pubspec.yaml`
  /// once `shaders/liquid_fluid.frag` exists).
  static const String liquidFluid = 'shaders/liquid_fluid.frag';

  /// Asset key for the SiriGlowEdge shader (registered in `pubspec.yaml`
  /// once `shaders/siri_edge.frag` exists).
  static const String siriEdge = 'shaders/siri_edge.frag';

  /// Loads (and caches) the [ui.FragmentProgram] for [assetKey]. [loader]
  /// is injectable for tests; production callers omit it and get
  /// [ui.FragmentProgram.fromAsset].
  static Future<ui.FragmentProgram> load(
    String assetKey, {
    Future<ui.FragmentProgram> Function(String)? loader,
  }) {
    return _programs.putIfAbsent(
      assetKey,
      () => (loader ?? ui.FragmentProgram.fromAsset)(assetKey),
    );
  }

  /// Clears the cache. Only for use in tests.
  static void debugClearForTesting() => _programs.clear();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/shader_warm_cache_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/core/shader_warm_cache.dart test/core/shader_warm_cache_test.dart
git commit -m "feat: add ShaderWarmCache shared shader loader"
```

---

## Task 6: LiquidGlow — `LiquidGlowPreset`

**Files:**
- Create: `lib/src/liquid_glow/liquid_glow_preset.dart`
- Test: `test/liquid_glow/liquid_glow_preset_test.dart`

**Interfaces:**
- Produces: `class LiquidGlowPreset { colors, baseSpeed, noiseScale }` with `.aurora()`, `.lavaLamp()`, `.cyberpunk()`, `.custom({required colors, required baseSpeed, required noiseScale})`. Consumed by `LiquidGlowController` (Task 7).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_preset.dart';

void main() {
  test('built-in presets each expose 2-6 colors and positive speed/scale',
      () {
    for (final preset in [
      const LiquidGlowPreset.aurora(),
      const LiquidGlowPreset.lavaLamp(),
      const LiquidGlowPreset.cyberpunk(),
    ]) {
      expect(preset.colors.length, inInclusiveRange(2, 6));
      expect(preset.baseSpeed, greaterThan(0));
      expect(preset.noiseScale, greaterThan(0));
    }
  });

  test('custom preset asserts color count is between 2 and 6', () {
    expect(
      () => LiquidGlowPreset.custom(
        colors: const [Color(0xFF000000)],
        baseSpeed: 1,
        noiseScale: 1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/liquid_glow/liquid_glow_preset_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/liquid_glow/liquid_glow_preset.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'package:flutter/painting.dart';

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
        noiseScale = 1.0;

  /// Dense, slow-moving warm colors.
  const LiquidGlowPreset.lavaLamp()
      : colors = const [
          Color(0xFFB3001B),
          Color(0xFFFF4D00),
          Color(0xFFFFA500),
        ],
        baseSpeed = 0.3,
        noiseScale = 1.6;

  /// Aggressive neon pink/cyan animation.
  const LiquidGlowPreset.cyberpunk()
      : colors = const [
          Color(0xFFFF00E5),
          Color(0xFF00F0FF),
          Color(0xFF7000FF),
        ],
        baseSpeed = 1.4,
        noiseScale = 0.8;

  /// A user-defined preset. [colors] must have between 2 and 6 entries.
  const LiquidGlowPreset.custom({
    required this.colors,
    required this.baseSpeed,
    required this.noiseScale,
  }) : assert(
          colors.length >= 2 && colors.length <= 6,
          'colors must have between 2 and 6 entries',
        );

  final List<Color> colors;
  final double baseSpeed;
  final double noiseScale;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/liquid_glow/liquid_glow_preset_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/liquid_glow/liquid_glow_preset.dart test/liquid_glow/liquid_glow_preset_test.dart
git commit -m "feat: add LiquidGlowPreset (aurora/lavaLamp/cyberpunk/custom)"
```

---

## Task 7: LiquidGlow — `LiquidGlowController`

**Files:**
- Create: `lib/src/controller/liquid_glow_controller.dart`
- Test: `test/controller/liquid_glow_controller_test.dart`

**Interfaces:**
- Consumes: `LiquidGlowPreset` (Task 6), `ColorMorph` (Task 4).
- Produces: `class LiquidGlowController extends ChangeNotifier` with:
  - Constructor `LiquidGlowController({LiquidGlowPreset preset = const LiquidGlowPreset.aurora(), double speed = 1.0, double intensity = 1.0, AlignmentGeometry origin = Alignment.center})`
  - `void play()`, `void pause()`, `void stop()`
  - `Future<void> animateToColors(List<Color> newColors, {Duration duration = const Duration(milliseconds: 800), Curve curve = Curves.easeInOut})`
  - `double speed` (get/set), `double intensity` (get/set), `AlignmentGeometry origin` (get/set), `Offset? touchOverride` (get/set)
  - `void bindIntensityStream(Stream<double> stream, {double Function(double raw)? mapper})`, `void unbindIntensityStream()`
  - `bool get isPlaying`, `LiquidGlowPreset get preset`, `List<Color> get colors`, `int get resetToken` (bumped by `stop()`; consumed by `LiquidGlow`'s State to reset elapsed time, Task 9)
  - `@override void dispose()`
  Consumed by `LiquidGlow` (Task 9) and the example app (Task 14).

- [ ] **Step 1: Write the failing test**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/controller/liquid_glow_controller.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_preset.dart';

void main() {
  testWidgets('play/pause/stop toggle isPlaying and bump resetToken',
      (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);
    expect(controller.isPlaying, isTrue);

    controller.pause();
    expect(controller.isPlaying, isFalse);

    controller.play();
    expect(controller.isPlaying, isTrue);

    final tokenBefore = controller.resetToken;
    controller.stop();
    expect(controller.isPlaying, isFalse);
    expect(controller.resetToken, isNot(tokenBefore));
  });

  testWidgets('animateToColors interpolates colors and resolves',
      (tester) async {
    final controller = LiquidGlowController(
      preset: const LiquidGlowPreset.custom(
        colors: [Color(0xFF000000), Color(0xFF000000)],
        baseSpeed: 1,
        noiseScale: 1,
      ),
    );
    addTearDown(controller.dispose);

    var completed = false;
    unawaited(controller
        .animateToColors(
          const [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          duration: const Duration(milliseconds: 100),
        )
        .then((_) => completed = true));

    // A Ticker's very first delivered frame always reports elapsed ==
    // Duration.zero (see Task 4's ColorMorph test) — pump once with no
    // duration to consume that baseline frame first.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(completed, isFalse);

    await tester.pump(const Duration(milliseconds: 60));
    expect(completed, isTrue);
    expect(controller.colors, [const Color(0xFFFFFFFF), const Color(0xFFFFFFFF)]);
  });

  testWidgets('bindIntensityStream applies mapper and notifies listeners',
      (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);
    final streamController = StreamController<double>();
    addTearDown(streamController.close);

    var notifyCount = 0;
    controller.addListener(() => notifyCount++);
    controller.bindIntensityStream(
      streamController.stream,
      mapper: (raw) => raw * 2,
    );

    streamController.add(0.25);
    await tester.pump();

    expect(controller.intensity, 0.5);
    expect(notifyCount, greaterThan(0));

    controller.unbindIntensityStream();
    final countAfterUnbind = notifyCount;
    streamController.add(0.9);
    await tester.pump();
    expect(notifyCount, countAfterUnbind);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controller/liquid_glow_controller_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/controller/liquid_glow_controller.dart'`

- [ ] **Step 3: Write minimal implementation**

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/color_morph.dart';
import '../liquid_glow/liquid_glow_preset.dart';

/// Reactive controller for [LiquidGlow]: playback, live-tunable
/// speed/intensity/origin, smooth color morphing, and binding an external
/// intensity stream (e.g. audio levels).
class LiquidGlowController extends ChangeNotifier {
  LiquidGlowController({
    LiquidGlowPreset preset = const LiquidGlowPreset.aurora(),
    double speed = 1.0,
    double intensity = 1.0,
    AlignmentGeometry origin = Alignment.center,
  })  : _preset = preset,
        _speed = speed,
        _intensity = intensity,
        _origin = origin;

  final LiquidGlowPreset _preset;
  double _speed;
  double _intensity;
  AlignmentGeometry _origin;
  Offset? _touchOverride;
  bool _isPlaying = true;
  int _resetToken = 0;
  List<Color> _displayColors = const [];

  ColorMorph? _morph;
  StreamSubscription<double>? _intensitySub;

  LiquidGlowPreset get preset => _preset;

  List<Color> get colors =>
      _displayColors.isEmpty ? _preset.colors : _displayColors;

  double get speed => _speed;
  set speed(double value) {
    if (_speed == value) return;
    _speed = value;
    notifyListeners();
  }

  double get intensity => _intensity;
  set intensity(double value) {
    if (_intensity == value) return;
    _intensity = value;
    notifyListeners();
  }

  AlignmentGeometry get origin => _origin;
  set origin(AlignmentGeometry value) {
    if (_origin == value) return;
    _origin = value;
    notifyListeners();
  }

  /// Programmatic override for the touch-reaction focal point, in local
  /// widget coordinates normalized to 0..1. `null` means no override.
  Offset? get touchOverride => _touchOverride;
  set touchOverride(Offset? value) {
    _touchOverride = value;
    notifyListeners();
  }

  bool get isPlaying => _isPlaying;

  /// Bumped by [stop]; `LiquidGlow` watches this to reset its elapsed-time
  /// uniform to zero.
  int get resetToken => _resetToken;

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _resetToken++;
    notifyListeners();
  }

  /// Smoothly morphs the displayed colors to [newColors] over [duration].
  Future<void> animateToColors(
    List<Color> newColors, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOut,
  }) {
    _morph ??= ColorMorph(
      onUpdate: (updated) {
        _displayColors = updated;
        notifyListeners();
      },
    );
    return _morph!.animate(
      from: colors,
      to: newColors,
      duration: duration,
      curve: curve,
    );
  }

  /// Subscribes to [stream], updating [intensity] on every event (through
  /// [mapper] if given). Replaces any previous binding.
  void bindIntensityStream(
    Stream<double> stream, {
    double Function(double raw)? mapper,
  }) {
    _intensitySub?.cancel();
    _intensitySub = stream.listen((raw) {
      intensity = mapper != null ? mapper(raw) : raw;
    });
  }

  void unbindIntensityStream() {
    _intensitySub?.cancel();
    _intensitySub = null;
  }

  @override
  void dispose() {
    _intensitySub?.cancel();
    _morph?.dispose();
    super.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controller/liquid_glow_controller_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/controller/liquid_glow_controller.dart test/controller/liquid_glow_controller_test.dart
git commit -m "feat: add LiquidGlowController"
```

---

## Task 8: LiquidGlow — `liquid_fluid.frag` shader

**Files:**
- Create: `shaders/liquid_fluid.frag`
- Modify: `pubspec.yaml` (add `flutter: shaders:` section)
- Create: `test/shaders/shader_load_test.dart`

**Interfaces:**
- Produces: a compiled shader at asset key `shaders/liquid_fluid.frag` loadable via `ShaderWarmCache.load(ShaderWarmCache.liquidFluid)` (Task 5). Its uniform contract (36 floats, `setFloat` index order) is consumed by `LiquidGlowPainter` (Task 9):
  1. `uSize` (vec2) → indices 0-1
  2. `uTime` (float) → index 2
  3. `uSpeed` (float) → index 3
  4. `uIntensity` (float) → index 4
  5. `uOrigin` (vec2, normalized 0..1) → indices 5-6
  6. `uTouch` (vec4: x, y normalized 0..1, strength, age seconds) → indices 7-10
  7. `uColorCount` (float) → index 11
  8. `uColor0`..`uColor5` (vec4 rgba, 0..1 each) → indices 12-35

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('liquid_fluid shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidFluid);
    expect(program, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/shaders/shader_load_test.dart`
Expected: FAIL — asset/shader not found (no `shaders/liquid_fluid.frag` file and no `flutter: shaders:` registration yet)

- [ ] **Step 3: Create `shaders/liquid_fluid.frag`**

```glsl
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
    fbm(aspectUv * 1.5 + vec2(0.0, t)),
    fbm(aspectUv * 1.5 + vec2(5.2, -t))
  );
  vec2 warped = aspectUv + warp * 0.5 * uIntensity;

  float n = fbm(warped * 2.0 + t);
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
```

- [ ] **Step 4: Register the shader in `pubspec.yaml`**

Add to `pubspec.yaml`:

```yaml
flutter:
  shaders:
    - shaders/liquid_fluid.frag
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter pub get && flutter test test/shaders/shader_load_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Commit**

```bash
git add shaders/liquid_fluid.frag pubspec.yaml test/shaders/shader_load_test.dart
git commit -m "feat: add liquid_fluid.frag domain-warped noise shader"
```

---

## Task 9: LiquidGlow — painter and widget

**Files:**
- Create: `lib/src/liquid_glow/touch_reaction.dart`
- Create: `lib/src/liquid_glow/liquid_glow_painter.dart`
- Create: `lib/src/liquid_glow/liquid_glow_widget.dart`
- Modify: `lib/liquid_glow.dart` (export the three new public types)
- Test: `test/widget/liquid_glow_lifecycle_test.dart`
- Test: `test/widget/reduce_motion_test.dart` (LiquidGlow half)

**Interfaces:**
- Consumes: `LiquidGlowController` (Task 7), `ShaderWarmCache` (Task 5), `GlowTickerMixin`/`liquidGlowRouteObserver` (Task 3), `ReduceMotion` (Task 2).
- Produces:
  - `class TouchReactionState { position, strength, age }` with `TouchReactionState.none()`.
  - `class LiquidGlowPainter extends CustomPainter` — packs the 36-float uniform buffer defined in Task 8 and draws via `canvas.drawRect`.
  - `class LiquidGlow extends StatefulWidget { controller, enableTouchReaction = false, child }`.
  Consumed by the example app (Task 14).

- [ ] **Step 1: Write the failing tests**

`test/widget/liquid_glow_lifecycle_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_painter.dart';

double _elapsedOf(WidgetTester tester) {
  final painter = tester
      .widget<CustomPaint>(find.byType(CustomPaint))
      .painter as LiquidGlowPainter;
  return painter.timeSeconds;
}

Future<void> _pumpApp(
  WidgetTester tester,
  LiquidGlowController controller, {
  bool tickerModeEnabled = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [liquidGlowRouteObserver],
      home: TickerMode(
        enabled: tickerModeEnabled,
        child: LiquidGlow(controller: controller),
      ),
    ),
  );
  // Let the async shader load complete.
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('advances time while playing and TickerMode is enabled',
      (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    final before = _elapsedOf(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_elapsedOf(tester), greaterThan(before));
  });

  testWidgets('does not advance time when TickerMode is disabled',
      (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller, tickerModeEnabled: false);

    final before = _elapsedOf(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_elapsedOf(tester), before);
  });

  testWidgets('does not advance time when controller is paused',
      (tester) async {
    final controller = LiquidGlowController()..pause();
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    final before = _elapsedOf(tester);
    await tester.pump(const Duration(milliseconds: 100));
    expect(_elapsedOf(tester), before);
  });
}
```

`test/widget/reduce_motion_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_painter.dart';

void main() {
  testWidgets('LiquidGlow freezes time when reduce motion is on',
      (tester) async {
    final controller = LiquidGlowController();
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

    final painter = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter as LiquidGlowPainter;
    final before = painter.timeSeconds;
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester
        .widget<CustomPaint>(find.byType(CustomPaint))
        .painter as LiquidGlowPainter;
    expect(after.timeSeconds, before);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/liquid_glow_lifecycle_test.dart test/widget/reduce_motion_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/liquid_glow/liquid_glow_painter.dart'` (and `LiquidGlow`/`liquidGlowRouteObserver` not exported from `liquid_glow.dart` yet)

- [ ] **Step 3: Create `lib/src/liquid_glow/touch_reaction.dart`**

```dart
import 'package:flutter/painting.dart';

/// The current touch-reaction bump state for [LiquidGlow]: a position
/// (normalized 0..1 in the widget's local bounds), a strength, and an age
/// in seconds since the touch began (used by the shader to decay the bump).
class TouchReactionState {
  const TouchReactionState({
    required this.position,
    required this.strength,
    required this.age,
  });

  factory TouchReactionState.none() =>
      const TouchReactionState(position: Offset.zero, strength: 0, age: 999);

  final Offset position;
  final double strength;
  final double age;

  @override
  bool operator ==(Object other) =>
      other is TouchReactionState &&
      other.position == position &&
      other.strength == strength &&
      other.age == age;

  @override
  int get hashCode => Object.hash(position, strength, age);
}
```

- [ ] **Step 4: Create `lib/src/liquid_glow/liquid_glow_painter.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../controller/liquid_glow_controller.dart';
import 'touch_reaction.dart';

/// Paints the LiquidGlow fluid shader, packing uniforms in the exact order
/// declared in `shaders/liquid_fluid.frag`.
class LiquidGlowPainter extends CustomPainter {
  LiquidGlowPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.touch,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;
  final TouchReactionState touch;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    final colors = controller.colors;
    final origin =
        controller.origin.resolve(TextDirection.ltr).alongSize(size);

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, origin.dx / size.width)
      ..setFloat(i++, origin.dy / size.height)
      ..setFloat(i++, touch.position.dx)
      ..setFloat(i++, touch.position.dy)
      ..setFloat(i++, touch.strength)
      ..setFloat(i++, touch.age)
      ..setFloat(i++, colors.length.toDouble());

    for (var c = 0; c < 6; c++) {
      // `.red`/`.green`/`.blue`/`.alpha` (int 0-255) are used rather than
      // the newer `.r`/`.g`/`.b`/`.a` (double 0-1) getters because the
      // package's SDK floor (Flutter 3.19) predates the latter.
      final color = c < colors.length ? colors[c] : colors.last;
      shader
        ..setFloat(i++, color.red / 255)
        ..setFloat(i++, color.green / 255)
        ..setFloat(i++, color.blue / 255)
        ..setFloat(i++, color.alpha / 255);
    }

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidGlowPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.touch != touch ||
        oldDelegate.controller != controller;
  }
}
```

- [ ] **Step 5: Create `lib/src/liquid_glow/liquid_glow_widget.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/liquid_glow_controller.dart';
import '../core/glow_ticker.dart';
import '../core/shader_warm_cache.dart';
import 'liquid_glow_painter.dart';
import 'touch_reaction.dart';

/// A GPU-shader-driven fluid glow background, driven by a
/// [LiquidGlowController]. Optionally reacts to touch/drag gestures.
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

  @override
  State<LiquidGlow> createState() => _LiquidGlowState();
}

class _LiquidGlowState extends State<LiquidGlow>
    with SingleTickerProviderStateMixin, GlowTickerMixin<LiquidGlow> {
  ui.FragmentProgram? _program;
  double _elapsedSeconds = 0;
  Duration _resetBaseline = Duration.zero;
  Duration _lastRawElapsed = Duration.zero;
  int _lastResetToken = -1;
  TouchReactionState _touch = TouchReactionState.none();

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _lastResetToken = widget.controller.resetToken;
    ShaderWarmCache.load(ShaderWarmCache.liquidFluid).then((program) {
      if (mounted) setState(() => _program = program);
    });
  }

  @override
  void didUpdateWidget(covariant LiquidGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.resetToken != _lastResetToken) {
      _lastResetToken = widget.controller.resetToken;
      _resetBaseline = _lastRawElapsed;
      _elapsedSeconds = 0;
    }
    setState(() {});
  }

  @override
  void onGlowTick(Duration elapsed) {
    // Always track the raw ticker clock (even while paused) so a later
    // stop()/reset can compute elapsed time relative to this moment.
    _lastRawElapsed = elapsed;
    if (!widget.controller.isPlaying) return;
    _elapsedSeconds =
        (elapsed - _resetBaseline).inMicroseconds /
            Duration.microsecondsPerSecond;
    if (_touch.strength > 0) {
      final age = _touch.age + 1 / 60;
      _touch = age > 1.5
          ? TouchReactionState.none()
          : TouchReactionState(
              position: _touch.position, strength: _touch.strength, age: age);
    }
    setState(() {});
  }

  void _handlePointer(Offset localPosition, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _touch = TouchReactionState(
        position: Offset(
          localPosition.dx / size.width,
          localPosition.dy / size.height,
        ),
        strength: 1.0,
        age: 0,
      );
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;

    Widget painterWidget = program == null
        ? const SizedBox.expand()
        : LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return CustomPaint(
                size: size,
                painter: LiquidGlowPainter(
                  program: program,
                  timeSeconds: _elapsedSeconds,
                  controller: widget.controller,
                  touch: _touch,
                ),
              );
            },
          );

    if (widget.enableTouchReaction) {
      painterWidget = LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onPanDown: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          onPanUpdate: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          child: painterWidget,
        ),
      );
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          painterWidget,
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Export the new public types from `lib/liquid_glow.dart`**

```dart
/// Shader-driven fluid glow backgrounds and an iOS 18-style Siri
/// screen-edge glow effect for Flutter.
library liquid_glow;

export 'src/controller/liquid_glow_controller.dart';
export 'src/core/glow_ticker.dart' show liquidGlowRouteObserver;
export 'src/liquid_glow/liquid_glow_preset.dart';
export 'src/liquid_glow/liquid_glow_widget.dart';
export 'src/liquid_glow/touch_reaction.dart';
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/widget/liquid_glow_lifecycle_test.dart test/widget/reduce_motion_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 8: Manually verify visual output**

Run a quick smoke check since shader pixel output isn't golden-tested: build the example app's `LiquidGlow` in isolation once Task 14 exists, or in the interim create a throwaway `flutter run` against `test/widget/liquid_glow_lifecycle_test.dart`'s app tree is not visual — defer full visual verification to Task 14's manual check. Note this in the commit message.

- [ ] **Step 9: Commit**

```bash
git add lib/src/liquid_glow/touch_reaction.dart lib/src/liquid_glow/liquid_glow_painter.dart lib/src/liquid_glow/liquid_glow_widget.dart lib/liquid_glow.dart test/widget/liquid_glow_lifecycle_test.dart test/widget/reduce_motion_test.dart
git commit -m "feat: add LiquidGlow widget and painter (visual check deferred to example app)"
```

---

## Task 10: SiriGlow — `GlowEdge`, `GlowEdgeMask`, `SiriGlowState`

**Files:**
- Create: `lib/src/siri_glow/glow_edge_mask.dart`
- Create: `lib/src/siri_glow/siri_glow_state.dart`
- Test: `test/siri_glow/glow_edge_mask_test.dart`

**Interfaces:**
- Produces:
  - `enum GlowEdge { top, right, bottom, left }`
  - `class GlowEdgeMask { edges }` with `GlowEdgeMask.all`, `.top`, `.bottom`, `.left`, `.right`, `operator |`, `showsTop`/`showsRight`/`showsBottom`/`showsLeft` getters, value equality.
  - `enum SiriGlowState { idle, listening, thinking, speaking }`
  Consumed by `SiriGlowEdge` (Task 12).

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/siri_glow/glow_edge_mask.dart';

void main() {
  test('GlowEdgeMask.all shows every edge', () {
    expect(GlowEdgeMask.all.showsTop, isTrue);
    expect(GlowEdgeMask.all.showsRight, isTrue);
    expect(GlowEdgeMask.all.showsBottom, isTrue);
    expect(GlowEdgeMask.all.showsLeft, isTrue);
  });

  test('single-edge presets show only that edge', () {
    expect(GlowEdgeMask.top.showsTop, isTrue);
    expect(GlowEdgeMask.top.showsBottom, isFalse);
    expect(GlowEdgeMask.top.showsLeft, isFalse);
    expect(GlowEdgeMask.top.showsRight, isFalse);
  });

  test('operator | combines edges', () {
    final combo = GlowEdgeMask.top | GlowEdgeMask.bottom;
    expect(combo.showsTop, isTrue);
    expect(combo.showsBottom, isTrue);
    expect(combo.showsLeft, isFalse);
    expect(combo.showsRight, isFalse);
  });

  test('value equality', () {
    expect(GlowEdgeMask.top | GlowEdgeMask.bottom,
        GlowEdgeMask.bottom | GlowEdgeMask.top);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/siri_glow/glow_edge_mask_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/siri_glow/glow_edge_mask.dart'`

- [ ] **Step 3: Write minimal implementation**

`lib/src/siri_glow/glow_edge_mask.dart`:

```dart
/// One edge of a [SiriGlowEdge]'s bounding rect.
enum GlowEdge { top, right, bottom, left }

/// Selects which edges of a [SiriGlowEdge] render the glow. Combine presets
/// with `|`, e.g. `GlowEdgeMask.top | GlowEdgeMask.bottom`.
class GlowEdgeMask {
  const GlowEdgeMask(this.edges);

  static const GlowEdgeMask all = GlowEdgeMask(
    {GlowEdge.top, GlowEdge.right, GlowEdge.bottom, GlowEdge.left},
  );
  static const GlowEdgeMask top = GlowEdgeMask({GlowEdge.top});
  static const GlowEdgeMask right = GlowEdgeMask({GlowEdge.right});
  static const GlowEdgeMask bottom = GlowEdgeMask({GlowEdge.bottom});
  static const GlowEdgeMask left = GlowEdgeMask({GlowEdge.left});

  final Set<GlowEdge> edges;

  bool get showsTop => edges.contains(GlowEdge.top);
  bool get showsRight => edges.contains(GlowEdge.right);
  bool get showsBottom => edges.contains(GlowEdge.bottom);
  bool get showsLeft => edges.contains(GlowEdge.left);

  GlowEdgeMask operator |(GlowEdgeMask other) =>
      GlowEdgeMask({...edges, ...other.edges});

  @override
  bool operator ==(Object other) =>
      other is GlowEdgeMask &&
      other.edges.length == edges.length &&
      other.edges.containsAll(edges);

  @override
  int get hashCode => Object.hashAllUnordered(edges);
}
```

`lib/src/siri_glow/siri_glow_state.dart`:

```dart
/// The current intonation mode of a [SiriGlowEdge].
enum SiriGlowState {
  /// Gentle, slow edge rotation.
  idle,

  /// Pulsating intonation.
  listening,

  /// Faster color cycling.
  thinking,

  /// High-intensity wave patterns.
  speaking,
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/siri_glow/glow_edge_mask_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add lib/src/siri_glow/glow_edge_mask.dart lib/src/siri_glow/siri_glow_state.dart test/siri_glow/glow_edge_mask_test.dart
git commit -m "feat: add GlowEdge/GlowEdgeMask and SiriGlowState"
```

---

## Task 11: SiriGlow — `siri_edge.frag` shader

**Files:**
- Create: `shaders/siri_edge.frag`
- Modify: `pubspec.yaml` (extend `flutter: shaders:` list)
- Modify: `test/shaders/shader_load_test.dart` (add siri_edge case)

**Interfaces:**
- Produces: a compiled shader at asset key `shaders/siri_edge.frag`. Its uniform contract (34 floats) is consumed by `SiriGlowPainter` (Task 12):
  1. `uSize` (vec2) → 0-1
  2. `uTime` (float) → 2
  3. `uBorderWidth` (float) → 3
  4. `uBlurRadius` (float) → 4
  5. `uCornerRadius` (vec4: topLeft, topRight, bottomRight, bottomLeft) → 5-8
  6. `uEdgeMask` (vec4: top, right, bottom, left as 0/1) → 9-12
  7. `uSpeed` (float) → 13
  8. `uPulse` (float) → 14
  9. `uWave` (float) → 15
  10. `uColorCycle` (float) → 16
  11. `uColorCount` (float) → 17
  12. `uColor0`..`uColor3` (vec4 rgba) → 18-33

- [ ] **Step 1: Extend the failing test**

Replace `test/shaders/shader_load_test.dart` with:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('liquid_fluid shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidFluid);
    expect(program, isNotNull);
  });

  test('siri_edge shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.siriEdge);
    expect(program, isNotNull);
  });
}
```

- [ ] **Step 2: Run test to verify the new case fails**

Run: `flutter test test/shaders/shader_load_test.dart`
Expected: FAIL on the `siri_edge` test — asset not found

- [ ] **Step 3: Create `shaders/siri_edge.frag`**

```glsl
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
  int lower = int(floor(scaled)) % count;
  int upper = (lower + 1) % count;
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

  float wavePhase = atan(p.y, p.x) * (2.0 + uWave * 4.0) - uTime * uSpeed * 1.5;
  float wave = 0.75 + 0.25 * sin(wavePhase);

  float colorPhase = fract(uTime * uColorCycle * 0.1 +
                            atan(p.y, p.x) / (2.0 * 3.14159265));
  vec4 color = rampColor(colorPhase);

  float alpha = glow * maskAlpha * wave;
  fragColor = vec4(color.rgb, color.a * alpha);
}
```

- [ ] **Step 4: Extend `pubspec.yaml`**

```yaml
flutter:
  shaders:
    - shaders/liquid_fluid.frag
    - shaders/siri_edge.frag
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter pub get && flutter test test/shaders/shader_load_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 6: Commit**

```bash
git add shaders/siri_edge.frag pubspec.yaml test/shaders/shader_load_test.dart
git commit -m "feat: add siri_edge.frag rounded-rect SDF glow shader"
```

---

## Task 12: SiriGlow — painter and widget

**Files:**
- Create: `lib/src/siri_glow/siri_glow_painter.dart`
- Create: `lib/src/siri_glow/siri_glow_edge.dart`
- Modify: `lib/liquid_glow.dart` (export new public types)
- Test: `test/widget/siri_glow_state_test.dart`
- Test: `test/widget/reduce_motion_test.dart` (add SiriGlowEdge case)

**Interfaces:**
- Consumes: `GlowEdge`/`GlowEdgeMask`/`SiriGlowState` (Task 10), `ShaderWarmCache` (Task 5), `GlowTickerMixin`/`liquidGlowRouteObserver` (Task 3), `ReduceMotion` (Task 2), the `siri_edge.frag` uniform contract (Task 11).
- Produces: `class SiriGlowEdge extends StatefulWidget { state, colors, borderRadius, borderWidth, blurRadius, mask, transitionDuration, child }`. Fully independent of `LiquidGlowController` — usable standalone or stacked over `LiquidGlow` via `Stack`.

- [ ] **Step 1: Write the failing tests**

`test/widget/siri_glow_state_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';

Future<void> _pumpApp(
  WidgetTester tester,
  SiriGlowState state, {
  Duration transitionDuration = const Duration(milliseconds: 400),
}) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [liquidGlowRouteObserver],
      home: SiriGlowEdge(
        state: state,
        transitionDuration: transitionDuration,
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('renders a CustomPaint once its shader has loaded',
      (tester) async {
    await _pumpApp(tester, SiriGlowState.idle);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('changing state does not throw and keeps rendering',
      (tester) async {
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [liquidGlowRouteObserver],
        home: SiriGlowEdge(key: key, state: SiriGlowState.idle),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [liquidGlowRouteObserver],
        home: SiriGlowEdge(key: key, state: SiriGlowState.speaking),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.byType(CustomPaint), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
```

Add to `test/widget/reduce_motion_test.dart`:

```dart
  testWidgets('SiriGlowEdge jumps to the target state instantly under reduce motion',
      (tester) async {
    final key = GlobalKey();
    Widget buildApp(SiriGlowState state) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: MaterialApp(
            navigatorObservers: [liquidGlowRouteObserver],
            home: SiriGlowEdge(
              key: key,
              state: state,
              transitionDuration: const Duration(seconds: 5),
            ),
          ),
        );

    await tester.pumpWidget(buildApp(SiriGlowState.idle));
    await tester.pump();
    await tester.pump();

    await tester.pumpWidget(buildApp(SiriGlowState.speaking));
    // A single pump (no elapsed time) is enough: under reduce motion the
    // widget should already be at the target state, not part-way through
    // a 5-second cross-fade.
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsWidgets);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/widget/siri_glow_state_test.dart test/widget/reduce_motion_test.dart`
Expected: FAIL — `Error: Not found: 'package:liquid_glow/src/siri_glow/siri_glow_edge.dart'` (and `SiriGlowEdge`/`SiriGlowState` not exported yet)

- [ ] **Step 3: Create `lib/src/siri_glow/siri_glow_painter.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'glow_edge_mask.dart';

/// Per-state animation parameters blended between the `from` and `to`
/// [SiriGlowState] during a cross-fade transition.
class SiriGlowParams {
  const SiriGlowParams({
    required this.speed,
    required this.pulse,
    required this.wave,
    required this.colorCycle,
  });

  final double speed;
  final double pulse;
  final double wave;
  final double colorCycle;

  static const idle = SiriGlowParams(
      speed: 0.3, pulse: 0.1, wave: 0.2, colorCycle: 0.15);
  static const listening = SiriGlowParams(
      speed: 0.8, pulse: 0.9, wave: 0.3, colorCycle: 0.3);
  static const thinking = SiriGlowParams(
      speed: 1.6, pulse: 0.4, wave: 0.5, colorCycle: 1.2);
  static const speaking = SiriGlowParams(
      speed: 2.2, pulse: 1.0, wave: 1.0, colorCycle: 0.8);

  static SiriGlowParams lerp(SiriGlowParams a, SiriGlowParams b, double t) {
    return SiriGlowParams(
      speed: ui.lerpDouble(a.speed, b.speed, t)!,
      pulse: ui.lerpDouble(a.pulse, b.pulse, t)!,
      wave: ui.lerpDouble(a.wave, b.wave, t)!,
      colorCycle: ui.lerpDouble(a.colorCycle, b.colorCycle, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SiriGlowParams &&
      other.speed == speed &&
      other.pulse == pulse &&
      other.wave == wave &&
      other.colorCycle == colorCycle;

  @override
  int get hashCode => Object.hash(speed, pulse, wave, colorCycle);
}

/// Paints the SiriGlowEdge shader, packing uniforms in the exact order
/// declared in `shaders/siri_edge.frag`.
class SiriGlowPainter extends CustomPainter {
  SiriGlowPainter({
    required this.program,
    required this.timeSeconds,
    required this.colors,
    required this.borderRadius,
    required this.borderWidth,
    required this.blurRadius,
    required this.mask,
    required this.params,
  });

  final ui.FragmentProgram program;
  final double timeSeconds;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double blurRadius;
  final GlowEdgeMask mask;
  final SiriGlowParams params;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    final r = borderRadius.resolve(TextDirection.ltr);

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, borderWidth)
      ..setFloat(i++, blurRadius)
      ..setFloat(i++, r.topLeft.x)
      ..setFloat(i++, r.topRight.x)
      ..setFloat(i++, r.bottomRight.x)
      ..setFloat(i++, r.bottomLeft.x)
      ..setFloat(i++, mask.showsTop ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsRight ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsBottom ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsLeft ? 1.0 : 0.0)
      ..setFloat(i++, params.speed)
      ..setFloat(i++, params.pulse)
      ..setFloat(i++, params.wave)
      ..setFloat(i++, params.colorCycle)
      ..setFloat(i++, colors.length.toDouble());

    for (var c = 0; c < 4; c++) {
      final color = c < colors.length ? colors[c] : colors.last;
      shader
        ..setFloat(i++, color.red / 255)
        ..setFloat(i++, color.green / 255)
        ..setFloat(i++, color.blue / 255)
        ..setFloat(i++, color.alpha / 255);
    }

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant SiriGlowPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.params != params ||
        oldDelegate.mask != mask ||
        oldDelegate.colors != colors ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.blurRadius != blurRadius;
  }
}
```

- [ ] **Step 4: Create `lib/src/siri_glow/siri_glow_edge.dart`**

```dart
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glow_ticker.dart';
import '../core/reduce_motion.dart';
import '../core/shader_warm_cache.dart';
import 'glow_edge_mask.dart';
import 'siri_glow_painter.dart';
import 'siri_glow_state.dart';

SiriGlowParams _paramsForState(SiriGlowState state) {
  switch (state) {
    case SiriGlowState.idle:
      return SiriGlowParams.idle;
    case SiriGlowState.listening:
      return SiriGlowParams.listening;
    case SiriGlowState.thinking:
      return SiriGlowParams.thinking;
    case SiriGlowState.speaking:
      return SiriGlowParams.speaking;
  }
}

/// An iOS 18-style Siri screen-edge glow. Fully independent of
/// [LiquidGlowController] — driven declaratively via [state], and usable
/// standalone or stacked over a [LiquidGlow] background.
class SiriGlowEdge extends StatefulWidget {
  const SiriGlowEdge({
    required this.state,
    this.colors = const [
      Color(0xFF7F5AF0),
      Color(0xFF2CB1E0),
      Color(0xFFE0526B),
    ],
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

  @override
  State<SiriGlowEdge> createState() => _SiriGlowEdgeState();
}

class _SiriGlowEdgeState extends State<SiriGlowEdge>
    with SingleTickerProviderStateMixin, GlowTickerMixin<SiriGlowEdge> {
  ui.FragmentProgram? _program;
  double _elapsedSeconds = 0;
  late AnimationController _transitionController;
  late SiriGlowState _fromState;
  late SiriGlowState _toState;

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void initState() {
    super.initState();
    _fromState = widget.state;
    _toState = widget.state;
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: 1.0,
    );
    ShaderWarmCache.load(ShaderWarmCache.siriEdge).then((program) {
      if (mounted) setState(() => _program = program);
    });
  }

  @override
  void didUpdateWidget(covariant SiriGlowEdge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _fromState = _transitionController.value >= 0.5 ? _toState : _fromState;
      _toState = widget.state;
      if (ReduceMotion.of(context)) {
        _transitionController.value = 1.0;
      } else {
        _transitionController
          ..duration = widget.transitionDuration
          ..forward(from: 0);
      }
    }
  }

  @override
  void onGlowTick(Duration elapsed) {
    _elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    setState(() {});
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final params = SiriGlowParams.lerp(
      _paramsForState(_fromState),
      _paramsForState(_toState),
      _transitionController.value,
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.child != null) widget.child!,
          if (program != null)
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: constraints.biggest,
                    painter: SiriGlowPainter(
                      program: program,
                      timeSeconds: _elapsedSeconds,
                      colors: widget.colors,
                      borderRadius: widget.borderRadius,
                      borderWidth: widget.borderWidth,
                      blurRadius: widget.blurRadius,
                      mask: widget.mask,
                      params: params,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Update `lib/liquid_glow.dart` exports**

```dart
/// Shader-driven fluid glow backgrounds and an iOS 18-style Siri
/// screen-edge glow effect for Flutter.
library liquid_glow;

export 'src/controller/liquid_glow_controller.dart';
export 'src/core/glow_ticker.dart' show liquidGlowRouteObserver;
export 'src/liquid_glow/liquid_glow_preset.dart';
export 'src/liquid_glow/liquid_glow_widget.dart';
export 'src/liquid_glow/touch_reaction.dart';
export 'src/siri_glow/glow_edge_mask.dart';
export 'src/siri_glow/siri_glow_edge.dart';
export 'src/siri_glow/siri_glow_state.dart';
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/widget/siri_glow_state_test.dart test/widget/reduce_motion_test.dart`
Expected: PASS (5 tests total across both files)

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS (all tests across every file created so far)

- [ ] **Step 8: Commit**

```bash
git add lib/src/siri_glow/siri_glow_painter.dart lib/src/siri_glow/siri_glow_edge.dart lib/liquid_glow.dart test/widget/siri_glow_state_test.dart test/widget/reduce_motion_test.dart
git commit -m "feat: add SiriGlowEdge widget and painter"
```

---

## Task 13: Public documentation

**Files:**
- Modify: `README.md` (create if not already present — Task 1 did not create it)
- Modify: `CHANGELOG.md`

**Interfaces:**
- Produces: pub.dev-facing documentation referencing the final real API surface (no new code).

- [ ] **Step 1: Create `README.md`**

```markdown
# liquid_glow

High-performance, shader-driven fluid glow backgrounds and an iOS
18-style Siri screen-edge glow effect for Flutter, powered by Impeller
fragment shaders. Targets iOS and Android.

## LiquidGlow

```dart
final controller = LiquidGlowController(
  preset: const LiquidGlowPreset.aurora(),
);

LiquidGlow(
  controller: controller,
  enableTouchReaction: true,
  child: const Center(child: Text('Hello')),
)
```

Drive it from anywhere:

```dart
controller.speed = 1.5;
controller.intensity = 0.8;
controller.animateToColors(
  const [Color(0xFFFF00E5), Color(0xFF00F0FF)],
  duration: const Duration(milliseconds: 600),
);
controller.bindIntensityStream(myAudioLevelStream, mapper: (db) => db / 100);
```

Presets: `LiquidGlowPreset.aurora()`, `.lavaLamp()`, `.cyberpunk()`, or
`.custom(colors: ..., baseSpeed: ..., noiseScale: ...)`.

## SiriGlowEdge

```dart
SiriGlowEdge(
  state: SiriGlowState.listening,
  mask: GlowEdgeMask.top | GlowEdgeMask.bottom,
  borderRadius: const BorderRadius.all(Radius.circular(48)),
  child: const MyScreen(),
)
```

`SiriGlowEdge` is fully independent of `LiquidGlowController` and can be
stacked over a `LiquidGlow` background with a plain `Stack`.

## Route-aware pausing (optional)

Both widgets automatically pause when the app is backgrounded, when
`TickerMode` is disabled, and when the OS "Reduce Motion" setting is on.
To also pause when covered by a pushed route, register the shared route
observer:

```dart
MaterialApp(
  navigatorObservers: [liquidGlowRouteObserver],
  home: const MyHomePage(),
)
```

## Accessibility

Both widgets read `MediaQuery.disableAnimations` and, when true, freeze on
a single static frame instead of animating.

## Platform support

iOS and Android only in this release (Impeller fragment shader support on
web/desktop is not yet targeted).
```

- [ ] **Step 2: Update `CHANGELOG.md`**

```markdown
## 0.1.0

* Initial release: `LiquidGlow` fluid shader background with
  `LiquidGlowController` (play/pause/stop, speed/intensity/origin,
  `animateToColors`, `bindIntensityStream`) and `.aurora()`/`.lavaLamp()`/
  `.cyberpunk()` presets.
* `SiriGlowEdge`: independent iOS 18-style screen-edge glow with
  `idle`/`listening`/`thinking`/`speaking` states and `GlowEdgeMask`
  per-edge masking.
* Automatic pausing on app background, `TickerMode` off, and route
  coverage; automatic reduce-motion fallback to a static frame.
```

- [ ] **Step 3: Verify analysis still passes**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add README.md CHANGELOG.md
git commit -m "docs: write README and changelog for 0.1.0"
```

---

## Task 14: Example app

**Files:**
- Create: `example/pubspec.yaml`
- Create: `example/analysis_options.yaml`
- Create: `example/lib/main.dart`

**Interfaces:**
- Consumes: the full public API exported from `lib/liquid_glow.dart` (Tasks 6, 7, 9, 10, 12).
- Produces: a runnable demo app — the only place shader visual output is verified in this plan (per spec, no golden tests).

- [ ] **Step 1: Create `example/pubspec.yaml`**

```yaml
name: liquid_glow_example
description: Example app demonstrating the liquid_glow package.
publish_to: 'none'
version: 0.1.0

environment:
  sdk: '>=3.3.0 <4.0.0'
  flutter: '>=3.19.0'

dependencies:
  flutter:
    sdk: flutter
  liquid_glow:
    path: ../

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

- [ ] **Step 2: Create `example/analysis_options.yaml`**

```yaml
include: package:flutter_lints/flutter.yaml
```

- [ ] **Step 3: Create `example/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:liquid_glow/liquid_glow.dart';

void main() => runApp(const LiquidGlowExampleApp());

class LiquidGlowExampleApp extends StatelessWidget {
  const LiquidGlowExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'liquid_glow example',
      navigatorObservers: [liquidGlowRouteObserver],
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final LiquidGlowController _controller;
  SiriGlowState _siriState = SiriGlowState.idle;
  GlowEdgeMask _mask = GlowEdgeMask.all;
  int _presetIndex = 0;

  static const _presets = [
    LiquidGlowPreset.aurora(),
    LiquidGlowPreset.lavaLamp(),
    LiquidGlowPreset.cyberpunk(),
  ];
  static const _presetLabels = ['Aurora', 'Lava Lamp', 'Cyberpunk'];

  static const _morphPalettes = [
    [Color(0xFFFF00E5), Color(0xFF00F0FF), Color(0xFF7000FF)],
    [Color(0xFF00C9A7), Color(0xFF6A5ACD), Color(0xFF1E90FF)],
    [Color(0xFFB3001B), Color(0xFFFF4D00), Color(0xFFFFA500)],
  ];
  int _morphIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = LiquidGlowController(preset: _presets[_presetIndex]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPreset(int index) {
    setState(() => _presetIndex = index);
    _controller.animateToColors(_presets[index].colors);
  }

  void _morphColors() {
    _morphIndex = (_morphIndex + 1) % _morphPalettes.length;
    _controller.animateToColors(
      _morphPalettes[_morphIndex],
      duration: const Duration(milliseconds: 900),
    );
  }

  void _toggleMaskEdge(GlowEdgeMask edge) {
    setState(() {
      _mask = _mask.edges.containsAll(edge.edges)
          ? GlowEdgeMask(_mask.edges.difference(edge.edges))
          : _mask | edge;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SiriGlowEdge(
        state: _siriState,
        mask: _mask,
        child: LiquidGlow(
          controller: _controller,
          enableTouchReaction: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'liquid_glow',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<int>(
                    segments: [
                      for (var i = 0; i < _presetLabels.length; i++)
                        ButtonSegment(value: i, label: Text(_presetLabels[i])),
                    ],
                    selected: {_presetIndex},
                    onSelectionChanged: (selection) =>
                        _selectPreset(selection.first),
                  ),
                  const SizedBox(height: 16),
                  Text('Speed: ${_controller.speed.toStringAsFixed(2)}'),
                  Slider(
                    value: _controller.speed,
                    min: 0.1,
                    max: 3.0,
                    onChanged: (value) =>
                        setState(() => _controller.speed = value),
                  ),
                  Text(
                      'Intensity: ${_controller.intensity.toStringAsFixed(2)}'),
                  Slider(
                    value: _controller.intensity,
                    min: 0.0,
                    max: 2.0,
                    onChanged: (value) =>
                        setState(() => _controller.intensity = value),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _morphColors,
                    child: const Text('Morph colors'),
                  ),
                  const SizedBox(height: 32),
                  const Text('Siri glow state',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final state in SiriGlowState.values)
                        ChoiceChip(
                          label: Text(state.name),
                          selected: _siriState == state,
                          onSelected: (_) =>
                              setState(() => _siriState = state),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Siri glow edges',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in {
                        'Top': GlowEdgeMask.top,
                        'Right': GlowEdgeMask.right,
                        'Bottom': GlowEdgeMask.bottom,
                        'Left': GlowEdgeMask.left,
                      }.entries)
                        FilterChip(
                          label: Text(entry.key),
                          selected:
                              _mask.edges.containsAll(entry.value.edges),
                          onSelected: (_) => _toggleMaskEdge(entry.value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Fetch example dependencies**

Run: `cd example && flutter pub get`
Expected: `Got dependencies!`

- [ ] **Step 5: Analyze the example**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Manually verify the visual output (required — no golden tests in this plan)**

Run: `flutter run` (from `example/`, on an iOS simulator or Android emulator/device)
Verify by hand:
- The Aurora/Lava Lamp/Cyberpunk segmented buttons each visibly change the background's palette and motion character.
- Dragging on the background produces a visible localized ripple/warp that decays over ~1.5s.
- The Speed and Intensity sliders visibly change animation speed and warp strength in real time.
- "Morph colors" smoothly cross-fades the background palette rather than snapping.
- Each Siri glow state chip visibly changes the edge glow's pulsation/speed/color-cycling character, cross-fading over ~400ms.
- Toggling Top/Right/Bottom/Left chips visibly adds/removes glow from that edge.
- With the OS "Reduce Motion" accessibility setting enabled (iOS Settings > Accessibility > Motion, or Android Settings > Accessibility > Remove animations), both the background and the edge glow stop animating and show a static frame.

- [ ] **Step 7: Commit**

```bash
cd /Users/ibrokhimal/PROJECTS/PACAGES/liquid_glow
git add example/pubspec.yaml example/analysis_options.yaml example/lib/main.dart
git commit -m "feat: add example app demonstrating presets, controller, and Siri glow states"
```

---

## Final Verification

- [ ] Run the full test suite once more from the package root: `flutter test`
  Expected: PASS, 0 failures.
- [ ] Run `flutter analyze` from both the package root and `example/`.
  Expected: `No issues found!` in both.
- [ ] Confirm `git log --oneline` shows one commit per task, in order.
