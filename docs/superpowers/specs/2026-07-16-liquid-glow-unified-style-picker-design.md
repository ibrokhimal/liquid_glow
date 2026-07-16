# liquid_glow — `fluid()` Preset + Unified Example Style Picker — Design Spec

Date: 2026-07-16
Status: Approved
Extends: `docs/superpowers/specs/2026-07-14-liquid-glow-design.md`,
`docs/superpowers/specs/2026-07-15-liquid-glow-shape-presets-design.md`

## Summary

Two changes:

1. Library: add a fourth named noise-kind preset,
   `LiquidGlowPreset.fluid()`, alongside the existing `.aurora()`,
   `.lavaLamp()`, `.cyberpunk()`.
2. Example app: replace the two separate `SegmentedButton`s (background
   style: Fluid/Dark Glow/Shapes; palette: Aurora/Lava Lamp/Cyberpunk)
   with a single style picker offering exactly one selection among 7
   options — **White, Fluid, Aurora, Lava Lamp, Cyberpunk, Dark Glow,
   Shapes** — with **White** selected by default on launch.

No shader, painter, or controller changes are needed: `fluid()` reuses
the existing `noise`-kind rendering path used by `aurora`/`lavaLamp`/
`cyberpunk`, and "White" in the example maps to no `LiquidGlow`/
controller at all (a plain white `Scaffold` background), not a new
preset.

## Goals

- One unified selector in the example app so a user picks exactly one of
  7 named styles, instead of two separate controls where "Fluid" and the
  palette picker overlapped in meaning.
- A distinct 4th noise palette (`fluid()`) so all three existing named
  palettes (aurora/lavaLamp/cyberpunk) keep their current identity and
  colors, and "Fluid" is a real fourth look rather than an alias for
  whichever of the three was last selected.
- "White" is a true no-op: no shader compiled, no controller
  constructed, just a plain white background. Selected by default.
- Controls that only make sense with an active controller (Speed,
  Intensity, Morph colors) are hidden when White is selected.

## Non-Goals

- No new shader/painter. `fluid()` is `LiquidGlowPresetKind.noise`, the
  same rendering path as the three existing noise presets.
- No changes to `LiquidGlowController`, `LiquidGlowPreset.custom()`,
  `darkGlow()`, or `floatingShapes()` — their existing behavior,
  including `floatingShapes()`'s own fixed white background, is
  unchanged. ("White" the example-app style and `floatingShapes()`'s
  internal white background are unrelated — the former is "no
  `LiquidGlow` at all," the latter is a specific shader-rendered
  preset.)
- No changes to `SiriGlowEdge`/Siri state controls in the example — out
  of scope, untouched by this change.
- No persistence of the selected style across app restarts — always
  starts on White, per the default-selection requirement.

## Library Change: `LiquidGlowPreset.fluid()`

Added to `lib/src/liquid_glow/liquid_glow_preset.dart`, following the
exact shape of the three existing noise-preset constructors:

```dart
/// Cool ocean-blue palette: light cyan, mid blue, pale aqua. Medium
/// speed, sitting between the calmer [aurora] and the faster
/// [cyberpunk].
const LiquidGlowPreset.fluid()
    : colors = const [
        Color(0xFF48CAE4),
        Color(0xFF0096C7),
        Color(0xFFCAF0F8),
      ],
      baseSpeed = 0.8,
      noiseScale = 1.2,
      backgroundColor = null,
      kind = LiquidGlowPresetKind.noise;
```

`README.md`'s preset list is updated to include `.fluid()` alongside the
other three.

## Example App Change: Unified Style Picker

### State shape

`_BackgroundStyle` (3 values) and the separate `_presetIndex`/`_presets`/
`_presetLabels` machinery are removed and replaced by a single enum and
nullable controller:

```dart
enum _GlowStyle { white, fluid, aurora, lavaLamp, cyberpunk, darkGlow, shapes }

_GlowStyle _style = _GlowStyle.white;
LiquidGlowController? _controller; // null only when _style == white
```

`initState` does **not** construct a controller (default is White, which
has none). `dispose` disposes `_controller` only if non-null.

### Style switching

```dart
void _selectStyle(_GlowStyle style) {
  if (style == _style) return;
  final oldController = _controller;
  setState(() {
    _style = style;
    _controller = switch (style) {
      _GlowStyle.white => null,
      _GlowStyle.fluid =>
        LiquidGlowController(preset: const LiquidGlowPreset.fluid()),
      _GlowStyle.aurora =>
        LiquidGlowController(preset: const LiquidGlowPreset.aurora()),
      _GlowStyle.lavaLamp =>
        LiquidGlowController(preset: const LiquidGlowPreset.lavaLamp()),
      _GlowStyle.cyberpunk =>
        LiquidGlowController(preset: const LiquidGlowPreset.cyberpunk()),
      _GlowStyle.darkGlow => LiquidGlowController(
          preset: const LiquidGlowPreset.darkGlow(
            backgroundColor: Color(0xFF0B0F1A),
          ),
        ),
      _GlowStyle.shapes =>
        LiquidGlowController(preset: const LiquidGlowPreset.floatingShapes()),
    };
  });
  oldController?.dispose();
}
```

The existing `_morphColors`/`_morphPalettes`/`_morphIndex` "Morph colors"
demo feature is kept as-is, operating on `_controller` when non-null
(unchanged from current behavior for the styles that already exist
today).

### Widget tree

```dart
Widget build(BuildContext context) {
  final controller = _controller;
  final content = SafeArea(/* existing Column of controls, unchanged
                               apart from the picker + conditional
                               Speed/Intensity/Morph below */);

  return Scaffold(
    backgroundColor: Colors.white, // only visible when controller == null
    body: SiriGlowEdge(
      state: _siriState,
      mask: _mask,
      child: controller == null
          ? content
          : LiquidGlow(
              controller: controller,
              enableTouchReaction: true,
              child: content,
            ),
    ),
  );
}
```

`Scaffold.backgroundColor` is set to white explicitly (rather than
relying on the app `ThemeData.dark()` default) so White reliably renders
as a plain white screen regardless of the app's overall dark theme.

### Picker UI

Single `Wrap` of `ChoiceChip`s (matching the existing pattern already
used for Siri glow state below it — this codebase doesn't use
`SegmentedButton` for 6+ options), replacing both current
`SegmentedButton`s:

```dart
Wrap(
  spacing: 8,
  children: [
    for (final style in _GlowStyle.values)
      ChoiceChip(
        label: Text(_styleLabel(style)),
        selected: _style == style,
        onSelected: (_) => _selectStyle(style),
      ),
  ],
),
```

with a label map `White / Fluid / Aurora / Lava Lamp / Cyberpunk / Dark
Glow / Shapes` (in `_GlowStyle.values` declaration order, so White is
first/leftmost as the default).

### Dependent controls follow controller nullability

Speed slider, Intensity slider, and the "Morph colors" button are
currently unconditionally rendered against `_controller` (which always
existed before this change). They now read `controller` (the local
nullable from `build`) and are omitted from the `Column` entirely when
`controller == null`:

```dart
if (controller != null) ...[
  Text('Speed: ${controller.speed.toStringAsFixed(2)}'),
  Slider(
    value: controller.speed,
    min: 0.1,
    max: 3.0,
    onChanged: (value) => setState(() => controller.speed = value),
  ),
  Text('Intensity: ${controller.intensity.toStringAsFixed(2)}'),
  Slider(
    value: controller.intensity,
    min: 0.0,
    max: 2.0,
    onChanged: (value) => setState(() => controller.intensity = value),
  ),
  const SizedBox(height: 16),
  ElevatedButton(
    onPressed: _morphColors,
    child: const Text('Morph colors'),
  ),
],
```

(Omitted, not disabled — greying out sliders bound to a null controller
has no clean Flutter idiom here; omitting the section is simpler and
unambiguous to the user.)

## Testing

- `test/liquid_glow/liquid_glow_preset_test.dart`: add a case for
  `LiquidGlowPreset.fluid()` mirroring the existing aurora/lavaLamp/
  cyberpunk cases — asserts `colors.length == 3`, `kind == noise`,
  `backgroundColor == null`, and that its colors differ from the other
  three noise presets (guards against picking a palette that visually
  collides with an existing one).
- Example app has no existing widget-test coverage (`example/` has no
  `test/` directory today) — none added, consistent with current
  practice. Manual verification: run the example, confirm White is
  selected on launch with a plain white screen and no Speed/Intensity/
  Morph controls visible, then click through all 7 chips confirming
  each renders distinctly and controls reappear for the 6 non-White
  styles.

## Migration Notes

This is example-app-only behavior change plus a purely additive library
API (`fluid()`); no breaking changes to `LiquidGlowPreset`,
`LiquidGlowController`, or any other public symbol. `CHANGELOG.md` gets
an entry noting the new `LiquidGlowPreset.fluid()` preset.
