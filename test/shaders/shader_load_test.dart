import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/shader_warm_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('liquid_fluid shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidFluid);
    expect(program, isNotNull);
  });

  test('siri_edge shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.siriEdge);
    expect(program, isNotNull);
  });

  test('liquid_orbs shader compiles and loads', () async {
    final program = await ShaderWarmCache.load(ShaderWarmCache.liquidOrbs);
    expect(program, isNotNull);
  });
}
