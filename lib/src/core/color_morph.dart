import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// Drives a smooth per-channel color-list interpolation over time,
/// independent of any [State]/`vsync` — used by
/// `LiquidGlowController.animateToColors`.
class ColorMorph {
  ColorMorph({required this.onUpdate});

  final ValueChanged<List<Color>> onUpdate;

  Ticker? _ticker;
  Completer<void>? _completer;

  /// Interpolates from [from] to [to] over [duration] using [curve],
  /// calling [onUpdate] on every tick. If [to] has a different length than
  /// [from], its entries are cycled to match.
  Future<void> animate({
    required List<Color> from,
    required List<Color> to,
    required Duration duration,
    required Curve curve,
  }) {
    _ticker?.dispose();
    final matchedTo = _matchLength(from, to);
    final completer = Completer<void>();
    _completer = completer;

    if (duration == Duration.zero) {
      onUpdate(matchedTo);
      completer.complete();
      return completer.future;
    }

    _ticker = Ticker((elapsed) {
      final t =
          (elapsed.inMicroseconds / duration.inMicroseconds).clamp(0.0, 1.0);
      final eased = curve.transform(t);
      onUpdate(<Color>[
        for (var i = 0; i < from.length; i++)
          Color.lerp(from[i], matchedTo[i], eased)!,
      ]);
      if (t >= 1.0) {
        _ticker?.stop();
        if (!completer.isCompleted) completer.complete();
      }
    });
    _ticker!.start();
    return completer.future;
  }

  List<Color> _matchLength(List<Color> from, List<Color> to) {
    if (to.length == from.length) return to;
    return List<Color>.generate(from.length, (i) => to[i % to.length]);
  }

  /// Cancels any in-flight animation. Does not complete the pending Future.
  void dispose() {
    _ticker?.dispose();
    _completer = null;
  }
}
