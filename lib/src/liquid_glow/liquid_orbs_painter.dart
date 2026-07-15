import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../controller/liquid_glow_controller.dart';
import 'shape_motion.dart';

/// Paints the LiquidGlow dark-orbs shader, packing uniforms in the exact
/// order declared in `shaders/liquid_orbs.frag`.
class LiquidOrbsPainter extends CustomPainter {
  LiquidOrbsPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.orbPositions,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;

  /// Normalized (0..1) positions of the 3 orbs, in uniform order. Compute
  /// with `computeShapePosition` against [motions].
  final List<Offset> orbPositions;

  static const Color _orbColor0 = Color(0xFF7F5AF0);
  static const Color _orbColor1 = Color(0xFF2CB1E0);
  static const double _orbRadius = 0.16;

  /// Fixed per-orb motion config: one of each kind, distinct phases so
  /// the three orbs never move in visual lockstep.
  static const List<ShapeMotionParams> motions = [
    ShapeMotionParams.orbital(
      center: Offset(0.5, 0.5), radius: 0.15, speed: 1.0, phase: 0),
    ShapeMotionParams.bounce(
      center: Offset(0.3, 0.6), radius: 0.12, speed: 1.0, phase: 2.1),
    ShapeMotionParams.travel(
      pointA: Offset(0.8, 0.2), pointB: Offset(0.3, 0.8),
      speed: 1.0, phase: 4.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    // darkGlow's constructor requires backgroundColor, so it is always
    // set on any preset that produces a LiquidOrbsPainter.
    final background = controller.preset.backgroundColor!;

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, background.red / 255)
      ..setFloat(i++, background.green / 255)
      ..setFloat(i++, background.blue / 255)
      ..setFloat(i++, background.alpha / 255)
      ..setFloat(i++, _orbColor0.red / 255)
      ..setFloat(i++, _orbColor0.green / 255)
      ..setFloat(i++, _orbColor0.blue / 255)
      ..setFloat(i++, _orbColor0.alpha / 255)
      ..setFloat(i++, _orbColor1.red / 255)
      ..setFloat(i++, _orbColor1.green / 255)
      ..setFloat(i++, _orbColor1.blue / 255)
      ..setFloat(i++, _orbColor1.alpha / 255);

    for (final pos in orbPositions) {
      shader
        ..setFloat(i++, pos.dx)
        ..setFloat(i++, pos.dy);
    }

    shader.setFloat(i++, _orbRadius);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidOrbsPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.orbPositions != orbPositions ||
        oldDelegate.controller != controller;
  }
}
