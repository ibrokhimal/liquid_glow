import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../controller/liquid_glow_controller.dart';
import '../core/glow_ticker.dart';
import '../core/shader_warm_cache.dart';
import 'liquid_glow_painter.dart';
import 'liquid_glow_preset.dart';
import 'liquid_orbs_painter.dart';
import 'liquid_shapes_painter.dart';
import 'shape_motion.dart';
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
  Offset? _lastAppliedTouchOverride;

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    _lastResetToken = widget.controller.resetToken;
    ShaderWarmCache.load(_shaderAssetKeyFor(widget.controller.preset.kind))
        .then((program) {
      if (mounted) setState(() => _program = program);
    });
    _applyTouchOverrideIfChanged();
  }

  @override
  void didUpdateWidget(covariant LiquidGlow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
      _lastResetToken = widget.controller.resetToken;
      _applyTouchOverrideIfChanged();
    }
  }

  void _applyTouchOverrideIfChanged() {
    final override = widget.controller.touchOverride;
    if (override == _lastAppliedTouchOverride) return;
    _lastAppliedTouchOverride = override;
    if (override != null) {
      _touch = TouchReactionState(position: override, strength: 1.0, age: 0);
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    _applyTouchOverrideIfChanged();
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

  String _shaderAssetKeyFor(LiquidGlowPresetKind kind) {
    switch (kind) {
      case LiquidGlowPresetKind.noise:
        return ShaderWarmCache.liquidFluid;
      case LiquidGlowPresetKind.darkOrbs:
        return ShaderWarmCache.liquidOrbs;
      case LiquidGlowPresetKind.floatingShapes:
        return ShaderWarmCache.liquidShapes;
    }
  }

  CustomPainter _buildPainter(ui.FragmentProgram program) {
    switch (widget.controller.preset.kind) {
      case LiquidGlowPresetKind.noise:
        return LiquidGlowPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          touch: _touch,
        );
      case LiquidGlowPresetKind.darkOrbs:
        return LiquidOrbsPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          orbPositions: [
            for (final motion in LiquidOrbsPainter.motions)
              computeShapePosition(
                  motion, _elapsedSeconds, widget.controller.speed),
          ],
        );
      case LiquidGlowPresetKind.floatingShapes:
        return LiquidShapesPainter(
          program: program,
          timeSeconds: _elapsedSeconds,
          controller: widget.controller,
          shapePositions: [
            for (final motion in LiquidShapesPainter.motions)
              computeShapePosition(
                  motion, _elapsedSeconds, widget.controller.speed),
          ],
        );
    }
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
                painter: _buildPainter(program),
              );
            },
          );

    if (widget.enableTouchReaction) {
      // Capture the pre-reassignment value: a closure over the
      // `painterWidget` variable itself (rather than this snapshot) would
      // see the *reassigned* LayoutBuilder as its own child once the
      // assignment below runs, since Dart closures capture variables, not
      // values — producing a widget that is its own child (infinite tree).
      final basePainterWidget = painterWidget;
      painterWidget = LayoutBuilder(
        builder: (context, constraints) => GestureDetector(
          onPanDown: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          onPanUpdate: (details) =>
              _handlePointer(details.localPosition, constraints.biggest),
          child: basePainterWidget,
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
