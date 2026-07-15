# liquid_glow

High-performance, shader-driven fluid glow backgrounds and an iOS
18-style Siri screen-edge glow effect for Flutter, powered by Impeller
fragment shaders. Targets iOS and Android.

## LiquidGlow

```dart
final controller = LiquidGlowController(
  preset: const LiquidGlowPreset.aurora(),
);

LiquidGlow(
  controller: controller,
  enableTouchReaction: true,
  child: const Center(child: Text('Hello')),
)
```

Drive it from anywhere:

```dart
controller.speed = 1.5;
controller.intensity = 0.8;
controller.animateToColors(
  const [Color(0xFFFF00E5), Color(0xFF00F0FF)],
  duration: const Duration(milliseconds: 600),
);
controller.bindIntensityStream(myAudioLevelStream, mapper: (db) => db / 100);
```

Presets: `LiquidGlowPreset.aurora()`, `.lavaLamp()`, `.cyberpunk()`, or
`.custom(colors: ..., baseSpeed: ..., noiseScale: ...)`.

## SiriGlowEdge

```dart
SiriGlowEdge(
  state: SiriGlowState.listening,
  mask: GlowEdgeMask.top | GlowEdgeMask.bottom,
  borderRadius: const BorderRadius.all(Radius.circular(48)),
  child: const MyScreen(),
)
```

`SiriGlowEdge` is fully independent of `LiquidGlowController` and can be
stacked over a `LiquidGlow` background with a plain `Stack`.

## Route-aware pausing (optional)

Both widgets automatically pause when the app is backgrounded, when
`TickerMode` is disabled, and when the OS "Reduce Motion" setting is on.
To also pause when covered by a pushed route, register the shared route
observer:

```dart
MaterialApp(
  navigatorObservers: [liquidGlowRouteObserver],
  home: const MyHomePage(),
)
```

## Accessibility

Both widgets read `MediaQuery.disableAnimations` and, when true, freeze on
a single static frame instead of animating.

## Platform support

iOS and Android only in this release (Impeller fragment shader support on
web/desktop is not yet targeted).
