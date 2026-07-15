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

  /// Asset key for the LiquidGlow dark-orbs shader (registered in
  /// `pubspec.yaml` once `shaders/liquid_orbs.frag` exists).
  static const String liquidOrbs = 'shaders/liquid_orbs.frag';

  /// Loads (and caches) the [ui.FragmentProgram] for [assetKey]. [loader]
  /// is injectable for tests; production callers omit it and get
  /// [ui.FragmentProgram.fromAsset].
  ///
  /// Flutter registers a package's declared assets under the bare
  /// [assetKey] only when that package is the root project (e.g. running
  /// `liquid_glow`'s own tests/example from within the package itself),
  /// and under a `packages/liquid_glow/`-prefixed key only when the
  /// package is consumed as a dependency of another app — never both at
  /// once. Since this code can't know at compile time which situation it
  /// will run in, it tries the bare key first and falls back to the
  /// prefixed key on failure.
  static Future<ui.FragmentProgram> load(
    String assetKey, {
    Future<ui.FragmentProgram> Function(String)? loader,
  }) {
    return _programs.putIfAbsent(
      assetKey,
      () => _loadWithPackagePrefixFallback(assetKey, loader),
    );
  }

  static Future<ui.FragmentProgram> _loadWithPackagePrefixFallback(
    String assetKey,
    Future<ui.FragmentProgram> Function(String)? loader,
  ) async {
    final effectiveLoader = loader ?? ui.FragmentProgram.fromAsset;
    try {
      return await effectiveLoader(assetKey);
    } catch (_) {
      return effectiveLoader('packages/liquid_glow/$assetKey');
    }
  }

  /// Clears the cache. Only for use in tests.
  static void debugClearForTesting() => _programs.clear();
}
