import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../controller/liquid_glow_controller.dart';
import 'shape_motion.dart';

/// Paints the LiquidGlow floating-shapes shader, packing uniforms in the
/// exact order declared in `shaders/liquid_shapes.frag`.
class LiquidShapesPainter extends CustomPainter {
  LiquidShapesPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.shapePositions,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;

  /// Normalized (0..1) positions of the 5 shapes, in uniform order.
  /// Compute with `computeShapePosition` against [motions].
  final List<Offset> shapePositions;

  static const Color _shapeColor0 = Color(0xFFFFADAD); // triangle
  static const Color _shapeColor1 = Color(0xFFA0E7E5); // roundedSquare
  static const Color _shapeColor2 = Color(0xFFFFD6A5); // circle
  static const double _shapeSize = 0.14;

  /// Fixed per-shape motion config, cycling motion kinds
  /// [orbital, bounce, travel, orbital, bounce] with distinct
  /// centers/phases so shapes don't overlap in timing.
  static const List<ShapeMotionParams> motions = [
    ShapeMotionParams.orbital(
      center: Offset(0.35, 0.4), radius: 0.18, speed: 1.0, phase: 0),
    ShapeMotionParams.bounce(
      center: Offset(0.65, 0.5), radius: 0.15, speed: 1.0, phase: 1.5),
    ShapeMotionParams.travel(
      pointA: Offset(0.85, 0.15), pointB: Offset(0.5, 0.75),
      speed: 1.0, phase: 3.0),
    ShapeMotionParams.orbital(
      center: Offset(0.6, 0.7), radius: 0.12, speed: 1.0, phase: 2.4),
    ShapeMotionParams.bounce(
      center: Offset(0.25, 0.65), radius: 0.1, speed: 1.0, phase: 0.8),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, _shapeColor0.red / 255)
      ..setFloat(i++, _shapeColor0.green / 255)
      ..setFloat(i++, _shapeColor0.blue / 255)
      ..setFloat(i++, _shapeColor0.alpha / 255)
      ..setFloat(i++, _shapeColor1.red / 255)
      ..setFloat(i++, _shapeColor1.green / 255)
      ..setFloat(i++, _shapeColor1.blue / 255)
      ..setFloat(i++, _shapeColor1.alpha / 255)
      ..setFloat(i++, _shapeColor2.red / 255)
      ..setFloat(i++, _shapeColor2.green / 255)
      ..setFloat(i++, _shapeColor2.blue / 255)
      ..setFloat(i++, _shapeColor2.alpha / 255);

    for (final pos in shapePositions) {
      shader
        ..setFloat(i++, pos.dx)
        ..setFloat(i++, pos.dy);
    }

    shader.setFloat(i++, _shapeSize);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidShapesPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.shapePositions != shapePositions ||
        oldDelegate.controller != controller;
  }
}
