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
      preset: LiquidGlowPreset.custom(
        colors: const [Color(0xFF000000), Color(0xFF000000)],
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
