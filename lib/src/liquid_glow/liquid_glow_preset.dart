import 'package:flutter/painting.dart';

/// Which shader-backed rendering algorithm a [LiquidGlowPreset] uses.
/// Exposed for `LiquidGlow`'s internal shader/painter dispatch — most
/// consumers only need the named preset constructors, not this directly.
enum LiquidGlowPresetKind { noise, darkOrbs, floatingShapes }

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
        noiseScale = 1.0,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// Dense, slow-moving warm colors.
  const LiquidGlowPreset.lavaLamp()
      : colors = const [
          Color(0xFFB3001B),
          Color(0xFFFF4D00),
          Color(0xFFFFA500),
        ],
        baseSpeed = 0.3,
        noiseScale = 1.6,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// Aggressive neon pink/cyan animation.
  const LiquidGlowPreset.cyberpunk()
      : colors = const [
          Color(0xFFFF00E5),
          Color(0xFF00F0FF),
          Color(0xFF7000FF),
        ],
        baseSpeed = 1.4,
        noiseScale = 0.8,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.noise;

  /// A user-defined preset. [colors] must have between 2 and 6 entries.
  const LiquidGlowPreset.custom({
    required this.colors,
    required this.baseSpeed,
    required this.noiseScale,
  })  : backgroundColor = null,
        kind = LiquidGlowPresetKind.noise,
        assert(
          colors.length >= 2 && colors.length <= 6,
          'colors must have between 2 and 6 entries',
        );

  /// A solid dark background (yours to choose) with 3 glowing orbs
  /// floating across it — orbiting, bouncing, and drifting corner-to-
  /// center in a mix of independent motions.
  const LiquidGlowPreset.darkGlow({required Color this.backgroundColor})
      : colors = const [],
        baseSpeed = 0,
        noiseScale = 0,
        kind = LiquidGlowPresetKind.darkOrbs;

  /// Solid white background with 5 shapes (triangles, rounded squares,
  /// circles) that merge into each other like liquid as they float.
  const LiquidGlowPreset.floatingShapes()
      : colors = const [],
        baseSpeed = 0,
        noiseScale = 0,
        backgroundColor = null,
        kind = LiquidGlowPresetKind.floatingShapes;

  final List<Color> colors;
  final double baseSpeed;
  final double noiseScale;

  /// Only set (non-null) for [LiquidGlowPresetKind.darkOrbs] (i.e.
  /// presets built via [darkGlow]).
  final Color? backgroundColor;

  final LiquidGlowPresetKind kind;
}
