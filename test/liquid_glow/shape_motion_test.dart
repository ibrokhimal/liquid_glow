import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/shape_motion.dart';

void main() {
  group('orbital', () {
    test('stays on the configured circle around center', () {
      const params = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5),
        radius: 0.2,
        speed: 1.0,
        phase: 0,
      );
      for (final t in [0.0, 0.7, 3.3, 10.0]) {
        final pos = computeShapePosition(params, t, 1.0);
        final dist = (pos - params.center).distance;
        expect(dist, closeTo(0.2, 1e-6));
      }
    });

    test('speed multiplier scales angular velocity', () {
      const slow = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5), radius: 0.2, speed: 1.0, phase: 0);
      const fast = ShapeMotionParams.orbital(
        center: Offset(0.5, 0.5), radius: 0.2, speed: 2.0, phase: 0);
      final posSlow = computeShapePosition(slow, 1.0, 1.0);
      final posFast = computeShapePosition(fast, 1.0, 1.0);
      // Fast orbit at t=1 should match slow orbit's angle at t=2.
      final posSlowAtDoubleT = computeShapePosition(slow, 2.0, 1.0);
      expect(posFast.dx, closeTo(posSlowAtDoubleT.dx, 1e-6));
      expect(posFast.dy, closeTo(posSlowAtDoubleT.dy, 1e-6));
      expect(posSlow, isNot(equals(posFast)));
    });
  });

  group('bounce', () {
    test('y stays within [center.dy - radius, center.dy], x is fixed', () {
      const params = ShapeMotionParams.bounce(
        center: Offset(0.4, 0.7),
        radius: 0.15,
        speed: 1.0,
        phase: 0,
      );
      for (final t in [0.0, 0.5, 1.0, 2.0, 5.0]) {
        final pos = computeShapePosition(params, t, 1.0);
        expect(pos.dx, 0.4);
        expect(pos.dy, lessThanOrEqualTo(0.7));
        expect(pos.dy, greaterThanOrEqualTo(0.7 - 0.15 - 1e-9));
      }
    });

    test('is periodic with period pi (since it uses |sin|)', () {
      const params = ShapeMotionParams.bounce(
        center: Offset(0.4, 0.7), radius: 0.15, speed: 1.0, phase: 0);
      final a = computeShapePosition(params, 0.6, 1.0);
      final b = computeShapePosition(params, 0.6 + math.pi, 1.0);
      expect(a.dy, closeTo(b.dy, 1e-6));
    });
  });

  group('travel', () {
    test('reaches pointA at the start of each period and pointB at the '
        'midpoint', () {
      const params = ShapeMotionParams.travel(
        pointA: Offset(0.8, 0.2),
        pointB: Offset(0.3, 0.8),
        speed: 1.0,
        phase: 0,
      );
      final atStart = computeShapePosition(params, 0.0, 1.0);
      final atMid = computeShapePosition(params, 0.5, 1.0);
      expect(atStart.dx, closeTo(0.8, 1e-6));
      expect(atStart.dy, closeTo(0.2, 1e-6));
      expect(atMid.dx, closeTo(0.3, 1e-6));
      expect(atMid.dy, closeTo(0.8, 1e-6));
    });

    test('ping-pongs back to pointA by the end of the period', () {
      const params = ShapeMotionParams.travel(
        pointA: Offset(0.8, 0.2), pointB: Offset(0.3, 0.8),
        speed: 1.0, phase: 0);
      final nearEnd = computeShapePosition(params, 0.999, 1.0);
      expect(nearEnd.dx, closeTo(0.8, 0.01));
      expect(nearEnd.dy, closeTo(0.2, 0.01));
    });
  });
}
