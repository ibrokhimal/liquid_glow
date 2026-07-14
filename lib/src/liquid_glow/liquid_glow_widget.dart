import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/liquid_glow_controller.dart';
import '../core/glow_ticker.dart';
import '../core/shader_warm_cache.dart';
import 'liquid_glow_painter.dart';
import 'touch_reaction.dart';

/// A GPU-shader-driven fluid glow background, driven by a
/// [LiquidGlowController]. Optionally reacts to touch/drag gestures.
class LiquidGlow extends StatefulWidget {
  const LiquidGlow({
    required this.controller,
    this.enableTouchReaction = false,
    this.child,
    super.key,
  });

  final LiquidGlowController controller;
  final bool enableTouchReaction;
  final Widget? child;

  @override
  State<LiquidGlow> createState() => _LiquidGlowState();
}

class _LiquidGlowState extends State<LiquidGlow>
    with SingleTickerProviderStateMixin, GlowTickerMixin<LiquidGlow> {
  ui.FragmentProgram? _program;
  double _elapsedSeconds = 0;
  Duration _resetBaseline = Duration.zero;
  Duration _lastRawElapsed = Duration.zero;
  int _lastResetToken = -1;
  TouchReactionState _touch = TouchReactionState.none();

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _lastResetToken = widget.controller.resetToken;
    ShaderWarmCache.load(ShaderWarmCache.liquidFluid).then((program) {
      if (mounted) setState(() => _program = program);
    });
  }

  @override
  void didUpdateWidget(covariant LiquidGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.resetToken != _lastResetToken) {
      _lastResetToken = widget.controller.resetToken;
      _resetBaseline = _lastRawElapsed;
      _elapsedSeconds = 0;
    }
    setState(() {});
  }

  @override
  void onGlowTick(Duration elapsed) {
    // Always track the raw ticker clock (even while paused) so a later
    // stop()/reset can compute elapsed time relative to this moment.
    _lastRawElapsed = elapsed;
    if (!widget.controller.isPlaying) return;
    _elapsedSeconds = (elapsed - _resetBaseline).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (_touch.strength > 0) {
      final age = _touch.age + 1 / 60;
      _touch = age > 1.5
          ? TouchReactionState.none()
          : TouchReactionState(
              position: _touch.position, strength: _touch.strength, age: age);
    }
    setState(() {});
  }

  void _handlePointer(Offset localPosition, Size size) {
    if (size.isEmpty) return;
    setState(() {
      _touch = TouchReactionState(
        position: Offset(
          localPosition.dx / size.width,
          localPosition.dy / size.height,
        ),
        strength: 1.0,
        age: 0,
      );
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;

    Widget painterWidget = program == null
        ? const SizedBox.expand()
        : LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return CustomPaint(
                size: size,
                painter: LiquidGlowPainter(
                  program: program,
                  timeSeconds: _elapsedSeconds,
                  controller: widget.controller,
                  touch: _touch,
                ),
              );
            },
          );

    if (widget.enableTouchReaction) {
      painterWidget = LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onPanDown: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          onPanUpdate: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          child: painterWidget,
        ),
      );
    }

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          painterWidget,
          if (widget.child != null) widget.child!,
        ],
      ),
    );
  }
}
