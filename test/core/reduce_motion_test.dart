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
