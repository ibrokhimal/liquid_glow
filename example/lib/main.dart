import 'package:flutter/material.dart';
import 'package:liquid_glow/liquid_glow.dart';

void main() => runApp(const LiquidGlowExampleApp());

class LiquidGlowExampleApp extends StatelessWidget {
  const LiquidGlowExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'liquid_glow example',
      navigatorObservers: [liquidGlowRouteObserver],
      theme: ThemeData.dark(useMaterial3: true),
      home: const DemoPage(),
    );
  }
}

class DemoPage extends StatefulWidget {
  const DemoPage({super.key});

  @override
  State<DemoPage> createState() => _DemoPageState();
}

class _DemoPageState extends State<DemoPage> {
  late final LiquidGlowController _controller;
  SiriGlowState _siriState = SiriGlowState.idle;
  GlowEdgeMask _mask = GlowEdgeMask.all;
  int _presetIndex = 0;

  static const _presets = [
    LiquidGlowPreset.aurora(),
    LiquidGlowPreset.lavaLamp(),
    LiquidGlowPreset.cyberpunk(),
  ];
  static const _presetLabels = ['Aurora', 'Lava Lamp', 'Cyberpunk'];

  static const _morphPalettes = [
    [Color(0xFFFF00E5), Color(0xFF00F0FF), Color(0xFF7000FF)],
    [Color(0xFF00C9A7), Color(0xFF6A5ACD), Color(0xFF1E90FF)],
    [Color(0xFFB3001B), Color(0xFFFF4D00), Color(0xFFFFA500)],
  ];
  int _morphIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = LiquidGlowController(preset: _presets[_presetIndex]);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _selectPreset(int index) {
    setState(() => _presetIndex = index);
    _controller.animateToColors(_presets[index].colors);
  }

  void _morphColors() {
    _morphIndex = (_morphIndex + 1) % _morphPalettes.length;
    _controller.animateToColors(
      _morphPalettes[_morphIndex],
      duration: const Duration(milliseconds: 900),
    );
  }

  void _toggleMaskEdge(GlowEdgeMask edge) {
    setState(() {
      _mask = _mask.edges.containsAll(edge.edges)
          ? GlowEdgeMask(_mask.edges.difference(edge.edges))
          : _mask | edge;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SiriGlowEdge(
        state: _siriState,
        mask: _mask,
        child: LiquidGlow(
          controller: _controller,
          enableTouchReaction: true,
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'liquid_glow',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  SegmentedButton<int>(
                    segments: [
                      for (var i = 0; i < _presetLabels.length; i++)
                        ButtonSegment(value: i, label: Text(_presetLabels[i])),
                    ],
                    selected: {_presetIndex},
                    onSelectionChanged: (selection) =>
                        _selectPreset(selection.first),
                  ),
                  const SizedBox(height: 16),
                  Text('Speed: ${_controller.speed.toStringAsFixed(2)}'),
                  Slider(
                    value: _controller.speed,
                    min: 0.1,
                    max: 3.0,
                    onChanged: (value) =>
                        setState(() => _controller.speed = value),
                  ),
                  Text(
                      'Intensity: ${_controller.intensity.toStringAsFixed(2)}'),
                  Slider(
                    value: _controller.intensity,
                    min: 0.0,
                    max: 2.0,
                    onChanged: (value) =>
                        setState(() => _controller.intensity = value),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _morphColors,
                    child: const Text('Morph colors'),
                  ),
                  const SizedBox(height: 32),
                  const Text('Siri glow state',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final state in SiriGlowState.values)
                        ChoiceChip(
                          label: Text(state.name),
                          selected: _siriState == state,
                          onSelected: (_) =>
                              setState(() => _siriState = state),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Siri glow edges',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final entry in {
                        'Top': GlowEdgeMask.top,
                        'Right': GlowEdgeMask.right,
                        'Bottom': GlowEdgeMask.bottom,
                        'Left': GlowEdgeMask.left,
                      }.entries)
                        FilterChip(
                          label: Text(entry.key),
                          selected:
                              _mask.edges.containsAll(entry.value.edges),
                          onSelected: (_) => _toggleMaskEdge(entry.value),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
