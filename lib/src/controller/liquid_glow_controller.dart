import 'dart:async';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../core/color_morph.dart';
import '../liquid_glow/liquid_glow_preset.dart';

/// Reactive controller for [LiquidGlow]: playback, live-tunable
/// speed/intensity/origin, smooth color morphing, and binding an external
/// intensity stream (e.g. audio levels).
class LiquidGlowController extends ChangeNotifier {
  LiquidGlowController({
    LiquidGlowPreset preset = const LiquidGlowPreset.aurora(),
    double speed = 1.0,
    double intensity = 1.0,
    AlignmentGeometry origin = Alignment.center,
  })  : _preset = preset,
        _speed = speed,
        _intensity = intensity,
        _origin = origin;

  final LiquidGlowPreset _preset;
  double _speed;
  double _intensity;
  AlignmentGeometry _origin;
  Offset? _touchOverride;
  bool _isPlaying = true;
  int _resetToken = 0;
  List<Color> _displayColors = const [];

  ColorMorph? _morph;
  StreamSubscription<double>? _intensitySub;

  LiquidGlowPreset get preset => _preset;

  List<Color> get colors =>
      _displayColors.isEmpty ? _preset.colors : _displayColors;

  double get speed => _speed;
  set speed(double value) {
    if (_speed == value) return;
    _speed = value;
    notifyListeners();
  }

  double get intensity => _intensity;
  set intensity(double value) {
    if (_intensity == value) return;
    _intensity = value;
    notifyListeners();
  }

  AlignmentGeometry get origin => _origin;
  set origin(AlignmentGeometry value) {
    if (_origin == value) return;
    _origin = value;
    notifyListeners();
  }

  /// Programmatic override for the touch-reaction focal point, in local
  /// widget coordinates normalized to 0..1. `null` means no override.
  Offset? get touchOverride => _touchOverride;
  set touchOverride(Offset? value) {
    _touchOverride = value;
    notifyListeners();
  }

  bool get isPlaying => _isPlaying;

  /// Bumped by [stop]; `LiquidGlow` watches this to reset its elapsed-time
  /// uniform to zero.
  int get resetToken => _resetToken;

  void play() {
    if (_isPlaying) return;
    _isPlaying = true;
    notifyListeners();
  }

  void pause() {
    if (!_isPlaying) return;
    _isPlaying = false;
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _resetToken++;
    notifyListeners();
  }

  /// Smoothly morphs the displayed colors to [newColors] over [duration].
  Future<void> animateToColors(
    List<Color> newColors, {
    Duration duration = const Duration(milliseconds: 800),
    Curve curve = Curves.easeInOut,
  }) {
    _morph ??= ColorMorph(
      onUpdate: (updated) {
        _displayColors = updated;
        notifyListeners();
      },
    );
    return _morph!.animate(
      from: colors,
      to: newColors,
      duration: duration,
      curve: curve,
    );
  }

  /// Subscribes to [stream], updating [intensity] on every event (through
  /// [mapper] if given). Replaces any previous binding.
  void bindIntensityStream(
    Stream<double> stream, {
    double Function(double raw)? mapper,
  }) {
    _intensitySub?.cancel();
    _intensitySub = stream.listen((raw) {
      intensity = mapper != null ? mapper(raw) : raw;
    });
  }

  void unbindIntensityStream() {
    _intensitySub?.cancel();
    _intensitySub = null;
  }

  @override
  void dispose() {
    _intensitySub?.cancel();
    _morph?.dispose();
    super.dispose();
  }
}
