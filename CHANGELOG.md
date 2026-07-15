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
