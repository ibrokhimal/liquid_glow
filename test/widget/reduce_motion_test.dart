import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_painter.dart';

void main() {
  // See liquid_glow_lifecycle_test.dart for why this is needed: a cached,
  // already-completed shader-load Future from another test can leave
  // `.then()` callbacks tied to a torn-down test Zone.
  setUp(ShaderWarmCache.debugClearForTesting);

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

    // Scoped to descendants of LiquidGlow: MaterialApp's debug banner also
    // renders a CustomPaint (with a null `painter`, via `foregroundPainter`),
    // so an unscoped `find.byType(CustomPaint)` matches more than one widget.
    final liquidGlowCustomPaint = find.descendant(
      of: find.byType(LiquidGlow),
      matching: find.byType(CustomPaint),
    );

    final painter = tester.widget<CustomPaint>(liquidGlowCustomPaint).painter
        as LiquidGlowPainter;
    final before = painter.timeSeconds;
    await tester.pump(const Duration(milliseconds: 100));
    final after = tester.widget<CustomPaint>(liquidGlowCustomPaint).painter
        as LiquidGlowPainter;
    expect(after.timeSeconds, before);
  });

  testWidgets(
      'SiriGlowEdge jumps to the target state instantly under reduce motion',
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
}
