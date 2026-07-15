import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// How a shape/orb's position moves over time. Positions are always
/// normalized 0..1, matching the widget's local coordinate space.
enum ShapeMotionKind { orbital, bounce, travel }

/// Parameters for one shape/orb's motion. Construct via [orbital],
/// [bounce], or [travel] — the fields relevant to other kinds are unused
/// zero/identity values, kept only so [computeShapePosition] can accept a
/// single uniform parameter type.
class ShapeMotionParams {
  const ShapeMotionParams.orbital({
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.orbital,
        pointA = Offset.zero,
        pointB = Offset.zero;

  const ShapeMotionParams.bounce({
    required this.center,
    required this.radius,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.bounce,
        pointA = Offset.zero,
        pointB = Offset.zero;

  const ShapeMotionParams.travel({
    required this.pointA,
    required this.pointB,
    required this.speed,
    required this.phase,
  })  : kind = ShapeMotionKind.travel,
        center = Offset.zero,
        radius = 0;

  final ShapeMotionKind kind;

  /// orbital: orbit center. bounce: base position (x is fixed, y bounces
  /// upward from here). Unused for travel.
  final Offset center;

  /// orbital: orbit radius. bounce: bounce height. Unused for travel.
  final double radius;

  /// Per-shape multiplier applied on top of the caller-supplied global
  /// speed in [computeShapePosition].
  final double speed;

  /// Time offset (radians for orbital/bounce, a 0..1-ish offset for
  /// travel) so shapes with identical motion kinds don't move in sync.
  final double phase;

  /// travel: ping-pong endpoint A (normalized 0..1). Unused otherwise.
  final Offset pointA;

  /// travel: ping-pong endpoint B (normalized 0..1). Unused otherwise.
  final Offset pointB;
}

/// Computes a shape's normalized (0..1) position at elapsed time [t]
/// seconds, additionally scaled by the caller's live [speed] (typically
/// `LiquidGlowController.speed`).
Offset computeShapePosition(ShapeMotionParams params, double t, double speed) {
  final effectiveT = t * speed;
  switch (params.kind) {
    case ShapeMotionKind.orbital:
      final angle = effectiveT * params.speed + params.phase;
      return params.center +
          Offset(math.cos(angle), math.sin(angle)) * params.radius;
    case ShapeMotionKind.bounce:
      final bounceT = effectiveT * params.speed + params.phase;
      return Offset(
        params.center.dx,
        params.center.dy - math.sin(bounceT).abs() * params.radius,
      );
    case ShapeMotionKind.travel:
      final raw = (effectiveT * params.speed + params.phase) % 1.0;
      final triangle = raw < 0.5 ? raw * 2 : 2 - raw * 2;
      return Offset.lerp(params.pointA, params.pointB, triangle)!;
  }
}
