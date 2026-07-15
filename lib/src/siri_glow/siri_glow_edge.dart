import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../core/glow_ticker.dart';
import '../core/reduce_motion.dart';
import '../core/shader_warm_cache.dart';
import 'glow_edge_mask.dart';
import 'siri_glow_painter.dart';
import 'siri_glow_state.dart';

SiriGlowParams _paramsForState(SiriGlowState state) {
  switch (state) {
    case SiriGlowState.idle:
      return SiriGlowParams.idle;
    case SiriGlowState.listening:
      return SiriGlowParams.listening;
    case SiriGlowState.thinking:
      return SiriGlowParams.thinking;
    case SiriGlowState.speaking:
      return SiriGlowParams.speaking;
  }
}

/// An iOS 18-style Siri screen-edge glow. Fully independent of
/// [LiquidGlowController] — driven declaratively via [state], and usable
/// standalone or stacked over a [LiquidGlow] background.
class SiriGlowEdge extends StatefulWidget {
  const SiriGlowEdge({
    required this.state,
    this.colors = const [
      Color(0xFF7F5AF0),
      Color(0xFF2CB1E0),
      Color(0xFFE0526B),
    ],
    this.borderRadius = const BorderRadius.all(Radius.circular(48)),
    this.borderWidth = 6.0,
    this.blurRadius = 24.0,
    this.mask = GlowEdgeMask.all,
    this.transitionDuration = const Duration(milliseconds: 400),
    this.child,
    super.key,
  });

  final SiriGlowState state;
  final List<Color> colors;
  final BorderRadius borderRadius;
  final double borderWidth;
  final double blurRadius;
  final GlowEdgeMask mask;
  final Duration transitionDuration;
  final Widget? child;

  @override
  State<SiriGlowEdge> createState() => _SiriGlowEdgeState();
}

class _SiriGlowEdgeState extends State<SiriGlowEdge>
    with TickerProviderStateMixin, GlowTickerMixin<SiriGlowEdge> {
  ui.FragmentProgram? _program;
  double _elapsedSeconds = 0;
  late AnimationController _transitionController;
  late SiriGlowState _fromState;
  late SiriGlowState _toState;

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void initState() {
    super.initState();
    _fromState = widget.state;
    _toState = widget.state;
    _transitionController = AnimationController(
      vsync: this,
      duration: widget.transitionDuration,
      value: 1.0,
    );
    ShaderWarmCache.load(ShaderWarmCache.siriEdge).then((program) {
      if (mounted) setState(() => _program = program);
    });
  }

  @override
  void didUpdateWidget(covariant SiriGlowEdge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _fromState = _transitionController.value >= 0.5 ? _toState : _fromState;
      _toState = widget.state;
      if (ReduceMotion.of(context)) {
        _transitionController.value = 1.0;
      } else {
        _transitionController
          ..duration = widget.transitionDuration
          ..forward(from: 0);
      }
    }
  }

  @override
  void onGlowTick(Duration elapsed) {
    _elapsedSeconds = elapsed.inMicroseconds / Duration.microsecondsPerSecond;
    setState(() {});
  }

  @override
  void dispose() {
    _transitionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final program = _program;
    final params = SiriGlowParams.lerp(
      _paramsForState(_fromState),
      _paramsForState(_toState),
      _transitionController.value,
    );

    return RepaintBoundary(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (widget.child != null) widget.child!,
          if (program != null)
            IgnorePointer(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return CustomPaint(
                    size: constraints.biggest,
                    painter: SiriGlowPainter(
                      program: program,
                      timeSeconds: _elapsedSeconds,
                      colors: widget.colors,
                      borderRadius: widget.borderRadius,
                      borderWidth: widget.borderWidth,
                      blurRadius: widget.blurRadius,
                      mask: widget.mask,
                      params: params,
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
