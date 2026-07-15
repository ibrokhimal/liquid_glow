## 0.2.0

* Added `LiquidGlowPreset.darkGlow({required backgroundColor})`: 3 glowing
  orbs (orbiting, bouncing, and traveling corner-to-center) merging via
  GLSL SDF blending over a developer-chosen dark background.
* Added `LiquidGlowPreset.floatingShapes()`: 5 shapes (triangles, rounded
  squares, circles) merging into a liquid-like composition over a solid
  white background.

## 0.1.0

* Initial release: `LiquidGlow` fluid shader background with
  `LiquidGlowController` (play/pause/stop, speed/intensity/origin,
  `animateToColors`, `bindIntensityStream`) and `.aurora()`/`.lavaLamp()`/
  `.cyberpunk()` presets.
* `SiriGlowEdge`: independent iOS 18-style screen-edge glow with
  `idle`/`listening`/`thinking`/`speaking` states and `GlowEdgeMask`
  per-edge masking.
* Automatic pausing on app background, `TickerMode` off, and route
  coverage; automatic reduce-motion fallback to a static frame.
