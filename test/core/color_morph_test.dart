import 'dart:async';

import 'package:flutter/animation.dart';
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

  testWidgets('a second animate() call completes the first call\'s Future',
      (tester) async {
    final morph = ColorMorph(onUpdate: (_) {});
    addTearDown(morph.dispose);

    var firstCompleted = false;
    unawaited(morph
        .animate(
          from: const [Color(0xFF000000)],
          to: const [Color(0xFFFFFFFF)],
          duration: const Duration(seconds: 10),
          curve: Curves.linear,
        )
        .then((_) => firstCompleted = true));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));
    expect(firstCompleted, isFalse);

    // Second call interrupts the first.
    await morph.animate(
      from: const [Color(0xFF000000)],
      to: const [Color(0xFF00FF00)],
      duration: Duration.zero,
      curve: Curves.linear,
    );

    expect(firstCompleted, isTrue);
  });
}
