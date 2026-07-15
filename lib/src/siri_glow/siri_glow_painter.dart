import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';

import 'glow_edge_mask.dart';

/// Per-state animation parameters blended between the `from` and `to`
/// [SiriGlowState] during a cross-fade transition.
class SiriGlowParams {
  const SiriGlowParams({
    required this.speed,
    required this.pulse,
    required this.wave,
    required this.colorCycle,
  });

  final double speed;
  final double pulse;
  final double wave;
  final double colorCycle;

  static const idle = SiriGlowParams(
      speed: 0.3, pulse: 0.1, wave: 0.2, colorCycle: 0.15);
  static const listening = SiriGlowParams(
      speed: 0.8, pulse: 0.9, wave: 0.3, colorCycle: 0.3);
  static const thinking = SiriGlowParams(
      speed: 1.6, pulse: 0.4, wave: 0.5, colorCycle: 1.2);
  static const speaking = SiriGlowParams(
      speed: 2.2, pulse: 1.0, wave: 1.0, colorCycle: 0.8);

  static SiriGlowParams lerp(SiriGlowParams a, SiriGlowParams b, double t) {
    return SiriGlowParams(
      speed: ui.lerpDouble(a.speed, b.speed, t)!,
      pulse: ui.lerpDouble(a.pulse, b.pulse, t)!,
      wave: ui.lerpDouble(a.wave, b.wave, t)!,
      colorCycle: ui.lerpDouble(a.colorCycle, b.colorCycle, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SiriGlowParams &&
      other.speed == speed &&
      other.pulse == pulse &&
      other.wave == wave &&
      other.colorCycle == colorCycle;

  @override
  int get hashCode => Object.hash(speed, pulse, wave, colorCycle);
}

/// Paints the SiriGlowEdge shader, packing uniforms in the exact order
/// declared in `shaders/siri_edge.frag`.
class SiriGlowPainter extends CustomPainter {
  SiriGlowPainter({
    required this.program,
    required this.timeSeconds,
    required this.colors,
    required this.borderRadius,
    required this.borderWidth,
    required this.blurRadius,
    required this.mask,
    required this.params,
  });

  final ui.FragmentProgram program;
  final double timeSeconds;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double blurRadius;
  final GlowEdgeMask mask;
  final SiriGlowParams params;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final shader = program.fragmentShader();
    final r = borderRadius.resolve(TextDirection.ltr);

    var i = 0;
    shader
      ..setFloat(i++, size.width)
      ..setFloat(i++, size.height)
      ..setFloat(i++, timeSeconds)
      ..setFloat(i++, borderWidth)
      ..setFloat(i++, blurRadius)
      ..setFloat(i++, r.topLeft.x)
      ..setFloat(i++, r.topRight.x)
      ..setFloat(i++, r.bottomRight.x)
      ..setFloat(i++, r.bottomLeft.x)
      ..setFloat(i++, mask.showsTop ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsRight ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsBottom ? 1.0 : 0.0)
      ..setFloat(i++, mask.showsLeft ? 1.0 : 0.0)
      ..setFloat(i++, params.speed)
      ..setFloat(i++, params.pulse)
      ..setFloat(i++, params.wave)
      ..setFloat(i++, params.colorCycle)
      ..setFloat(i++, colors.length.toDouble());

    for (var c = 0; c < 4; c++) {
      final color = c < colors.length ? colors[c] : colors.last;
      shader
        ..setFloat(i++, color.red / 255)
        ..setFloat(i++, color.green / 255)
        ..setFloat(i++, color.blue / 255)
        ..setFloat(i++, color.alpha / 255);
    }

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(covariant SiriGlowPainter oldDelegate) {
    return oldDelegate.timeSeconds != timeSeconds ||
        oldDelegate.params != params ||
        oldDelegate.mask != mask ||
        oldDelegate.colors != colors ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.borderWidth != borderWidth ||
        oldDelegate.blurRadius != blurRadius;
  }
}
