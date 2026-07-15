import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_shapes_painter.dart';

void main() {
  test('motions has exactly 5 entries', () {
    expect(LiquidShapesPainter.motions, hasLength(5));
  });
}
