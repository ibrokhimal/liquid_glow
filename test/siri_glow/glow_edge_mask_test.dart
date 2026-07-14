import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/siri_glow/glow_edge_mask.dart';

void main() {
  test('GlowEdgeMask.all shows every edge', () {
    expect(GlowEdgeMask.all.showsTop, isTrue);
    expect(GlowEdgeMask.all.showsRight, isTrue);
    expect(GlowEdgeMask.all.showsBottom, isTrue);
    expect(GlowEdgeMask.all.showsLeft, isTrue);
  });

  test('single-edge presets show only that edge', () {
    expect(GlowEdgeMask.top.showsTop, isTrue);
    expect(GlowEdgeMask.top.showsBottom, isFalse);
    expect(GlowEdgeMask.top.showsLeft, isFalse);
    expect(GlowEdgeMask.top.showsRight, isFalse);
  });

  test('operator | combines edges', () {
    final combo = GlowEdgeMask.top | GlowEdgeMask.bottom;
    expect(combo.showsTop, isTrue);
    expect(combo.showsBottom, isTrue);
    expect(combo.showsLeft, isFalse);
    expect(combo.showsRight, isFalse);
  });

  test('value equality', () {
    expect(GlowEdgeMask.top | GlowEdgeMask.bottom,
        GlowEdgeMask.bottom | GlowEdgeMask.top);
  });
}
