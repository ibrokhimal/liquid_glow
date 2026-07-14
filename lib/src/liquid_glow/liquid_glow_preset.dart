import 'package:flutter/painting.dart';

/// A named color/speed/scale configuration for [LiquidGlow].
class LiquidGlowPreset {
  /// Northern-lights palette: green, purple, blue. Slow, ambient motion.
  const LiquidGlowPreset.aurora()
      : colors = const [
          Color(0xFF00C9A7),
          Color(0xFF6A5ACD),
          Color(0xFF1E90FF),
        ],
        baseSpeed = 0.6,
        noiseScale = 1.0;

  /// Dense, slow-moving warm colors.
  const LiquidGlowPreset.lavaLamp()
      : colors = const [
          Color(0xFFB3001B),
          Color(0xFFFF4D00),
          Color(0xFFFFA500),
        ],
        baseSpeed = 0.3,
        noiseScale = 1.6;

  /// Aggressive neon pink/cyan animation.
  const LiquidGlowPreset.cyberpunk()
      : colors = const [
          Color(0xFFFF00E5),
          Color(0xFF00F0FF),
          Color(0xFF7000FF),
        ],
        baseSpeed = 1.4,
        noiseScale = 0.8;

  /// A user-defined preset. [colors] must have between 2 and 6 entries.
  ///
  /// Not a `const` constructor: Dart's constant evaluator cannot fold
  /// `List.length`, so an assert on the list length is incompatible with
  /// `const`. Construct with `LiquidGlowPreset.custom(...)` (no `const`).
  LiquidGlowPreset.custom({
    required this.colors,
    required this.baseSpeed,
    required this.noiseScale,
  }) : assert(
          colors.length >= 2 && colors.length <= 6,
          'colors must have between 2 and 6 entries',
        );

  final List<Color> colors;
  final double baseSpeed;
  final double noiseScale;
}
