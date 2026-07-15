import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/liquid_glow/liquid_glow_preset.dart';

void main() {
  test('built-in presets each expose 2-6 colors and positive speed/scale',
      () {
    for (final preset in [
      const LiquidGlowPreset.aurora(),
      const LiquidGlowPreset.lavaLamp(),
      const LiquidGlowPreset.cyberpunk(),
    ]) {
      expect(preset.colors.length, inInclusiveRange(2, 6));
      expect(preset.baseSpeed, greaterThan(0));
      expect(preset.noiseScale, greaterThan(0));
    }
  });

  test('custom preset asserts color count is between 2 and 6', () {
    expect(
      () => LiquidGlowPreset.custom(
        colors: const [Color(0xFF000000)],
        baseSpeed: 1,
        noiseScale: 1,
      ),
      throwsA(isA<AssertionError>()),
    );
  });

  test('darkGlow carries the given backgroundColor and darkOrbs kind', () {
    const preset = LiquidGlowPreset.darkGlow(backgroundColor: Color(0xFF0B0F1A));
    expect(preset.backgroundColor, const Color(0xFF0B0F1A));
    expect(preset.kind, LiquidGlowPresetKind.darkOrbs);
  });

  test('floatingShapes has no backgroundColor and floatingShapes kind', () {
    const preset = LiquidGlowPreset.floatingShapes();
    expect(preset.backgroundColor, isNull);
    expect(preset.kind, LiquidGlowPresetKind.floatingShapes);
  });

  test('noise-based presets default to kind noise with no backgroundColor',
      () {
    for (final preset in [
      const LiquidGlowPreset.aurora(),
      const LiquidGlowPreset.lavaLamp(),
      const LiquidGlowPreset.cyberpunk(),
    ]) {
      expect(preset.kind, LiquidGlowPresetKind.noise);
      expect(preset.backgroundColor, isNull);
    }
  });
}
