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
