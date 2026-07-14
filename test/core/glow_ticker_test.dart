import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glow/src/core/glow_ticker.dart';

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with SingleTickerProviderStateMixin, GlowTickerMixin<_Probe> {
  int tickCount = 0;

  @override
  RouteObserver<ModalRoute<void>>? get routeObserver => liquidGlowRouteObserver;

  @override
  void onGlowTick(Duration elapsed) {
    tickCount++;
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

_ProbeState _stateOf(WidgetTester tester) =>
    tester.state<_ProbeState>(find.byType(_Probe));

void main() {
  testWidgets('ticks while visible and stops when TickerMode is disabled',
      (tester) async {
    await tester.pumpWidget(const _Probe());
    await tester.pump(const Duration(milliseconds: 16));
    final afterVisible = _stateOf(tester).tickCount;
    expect(afterVisible, greaterThan(0));

    await tester.pumpWidget(
      const TickerMode(enabled: false, child: _Probe()),
    );
    final countAtDisable = _stateOf(tester).tickCount;
    await tester.pump(const Duration(milliseconds: 16));
    await tester.pump(const Duration(milliseconds: 16));
    expect(_stateOf(tester).tickCount, countAtDisable);
  });

  testWidgets('stops ticking when reduce motion is enabled', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: _Probe(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 16));
    expect(_stateOf(tester).tickCount, 0);
  });
}
