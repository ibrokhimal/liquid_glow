import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

void main() {
  test('load caches the program future per asset key', () {
    ShaderWarmCache.debugClearForTesting();
    var callCount = 0;
    Future<ui.FragmentProgram> fakeLoader(String key) {
      callCount++;
      return Completer<ui.FragmentProgram>().future;
    }

    final first =
        ShaderWarmCache.load('shaders/fake.frag', loader: fakeLoader);
    final second =
        ShaderWarmCache.load('shaders/fake.frag', loader: fakeLoader);

    expect(identical(first, second), isTrue);
    expect(callCount, 1);
  });

  test('load uses a distinct cache entry per asset key', () {
    ShaderWarmCache.debugClearForTesting();
    var callCount = 0;
    Future<ui.FragmentProgram> fakeLoader(String key) {
      callCount++;
      return Completer<ui.FragmentProgram>().future;
    }

    ShaderWarmCache.load('shaders/a.frag', loader: fakeLoader);
    ShaderWarmCache.load('shaders/b.frag', loader: fakeLoader);

    expect(callCount, 2);
  });
}
