import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import '../controller/liquid_glow_controller.dart';
import 'touch_reaction.dart';

/// Paints the LiquidGlow fluid shader, packing uniforms in the exact order
/// declared in `shaders/liquid_fluid.frag`.
class LiquidGlowPainter extends CustomPainter {
  LiquidGlowPainter({
    required this.program,
    required this.timeSeconds,
    required this.controller,
    required this.touch,
  }) : super(repaint: controller);

  final ui.FragmentProgram program;
  final double timeSeconds;
  final LiquidGlowController controller;
  final TouchReactionState touch;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    final colors = controller.colors;
    final origin = controller.origin.resolve(TextDirection.ltr).alongSize(size);

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, controller.speed * controller.preset.baseSpeed)
      ..setFloat(i++, controller.intensity)
      ..setFloat(i++, origin.dx / size.width)
      ..setFloat(i++, origin.dy / size.height)
      ..setFloat(i++, touch.position.dx)
      ..setFloat(i++, touch.position.dy)
      ..setFloat(i++, touch.strength)
      ..setFloat(i++, touch.age)
      ..setFloat(i++, colors.length.toDouble());

    for (var c = 0; c < 6; c++) {
      // `.red`/`.green`/`.blue`/`.alpha` (int 0-255) are used rather than
      // the newer `.r`/`.g`/`.b`/`.a` (double 0-1) getters because the
      // package's SDK floor (Flutter 3.19) predates the latter.
      final color = c < colors.length ? colors[c] : colors.last;
      shader
        ..setFloat(i++, color.red / 255)
        ..setFloat(i++, color.green / 255)
        ..setFloat(i++, color.blue / 255)
        ..setFloat(i++, color.alpha / 255);
    }

    shader.setFloat(i++, controller.preset.noiseScale);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant LiquidGlowPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.touch != touch ||
        oldDelegate.controller != controller;
  }
}
