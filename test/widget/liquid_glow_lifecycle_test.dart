import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_painter.dart';

// Scoped to descendants of LiquidGlow: MaterialApp's debug banner also
// renders a CustomPaint (with a null `painter`, via `foregroundPainter`),
// so an unscoped `find.byType(CustomPaint)` matches more than one widget.
final Finder _liquidGlowCustomPaint = find.descendant(
  of: find.byType(LiquidGlow),
  matching: find.byType(CustomPaint),
);

double _elapsedOf(WidgetTester tester) {
  final painter = tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter
      as LiquidGlowPainter;
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
  // The shader-program cache stores completed Futures keyed by asset path.
  // `flutter_test` runs each testWidgets body in its own Zone; a `.then()`
  // registered in one test on a Future that completed during a *previous*
  // test never fires within this test's pump cycles (its callback is tied
  // to the zone that was current when the Future completed). Clearing the
  // cache before each test forces a fresh load (and thus a fresh `.then()`
  // completion) inside the current test's zone.
  setUp(ShaderWarmCache.debugClearForTesting);

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

  testWidgets('touchOverride is applied to the painter touch state',
      (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);
    await _pumpApp(tester, controller);

    controller.touchOverride = const Offset(0.3, 0.7);
    await tester.pump();

    final painter = tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter
        as LiquidGlowPainter;
    expect(painter.touch.position, const Offset(0.3, 0.7));
    expect(painter.touch.strength, 1.0);
  });

  testWidgets(
      'enableTouchReaction builds without error and a drag updates the '
      'painter touch state', (tester) async {
    final controller = LiquidGlowController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [liquidGlowRouteObserver],
        home: LiquidGlow(controller: controller, enableTouchReaction: true),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(_liquidGlowCustomPaint, findsOneWidget);

    final gesture = await tester.startGesture(const Offset(200, 300));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final painter = tester.widget<CustomPaint>(_liquidGlowCustomPaint).painter
        as LiquidGlowPainter;
    expect(painter.touch.strength, 1.0);

    await gesture.up();
  });
}
