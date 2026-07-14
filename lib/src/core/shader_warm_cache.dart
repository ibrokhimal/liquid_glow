import 'dart:ui' as ui;

/// Loads and caches [ui.FragmentProgram]s so [LiquidGlow] and
/// [SiriGlowEdge] instances share one compiled shader each instead of each
/// widget instance re-loading its own.
class ShaderWarmCache {
  ShaderWarmCache._();

  static final Map<String, Future<ui.FragmentProgram>> _programs = {};

  /// Asset key for the LiquidGlow fluid shader (registered in `pubspec.yaml`
  /// once `shaders/liquid_fluid.frag` exists).
  static const String liquidFluid = 'shaders/liquid_fluid.frag';

  /// Asset key for the SiriGlowEdge shader (registered in `pubspec.yaml`
  /// once `shaders/siri_edge.frag` exists).
  static const String siriEdge = 'shaders/siri_edge.frag';

  /// Loads (and caches) the [ui.FragmentProgram] for [assetKey]. [loader]
  /// is injectable for tests; production callers omit it and get
  /// [ui.FragmentProgram.fromAsset].
  static Future<ui.FragmentProgram> load(
    String assetKey, {
    Future<ui.FragmentProgram> Function(String)? loader,
  }) {
    return _programs.putIfAbsent(
      assetKey,
      () => (loader ?? ui.FragmentProgram.fromAsset)(assetKey),
    );
  }

  /// Clears the cache. Only for use in tests.
  static void debugClearForTesting() => _programs.clear();
}
