import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/liquid_glow.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

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
  // See liquid_glow_lifecycle_test.dart for why this is needed: a cached,
  // already-completed shader-load Future from another test can leave
  // `.then()` callbacks tied to a torn-down test Zone.
  setUp(ShaderWarmCache.debugClearForTesting);

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
