import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'reduce_motion.dart';

/// Shared route observer. Add this to `MaterialApp.navigatorObservers` (or
/// `WidgetsApp.navigatorObservers`) so [GlowTickerMixin] can pause ticking
/// when a [LiquidGlow] or [SiriGlowEdge] is covered by a pushed route.
///
/// This is optional — without it, ticking still pauses correctly on app
/// background and `TickerMode`/reduce-motion, just not on route coverage.
final RouteObserver<ModalRoute<void>> liquidGlowRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// Gates a single [Ticker] behind app lifecycle, [TickerMode], route
/// visibility, and OS reduce-motion state, so glow widgets automatically
/// pause when backgrounded, offscreen, covered, or when the user has
/// requested reduced motion.
mixin GlowTickerMixin<T extends StatefulWidget> on State<T>
    implements TickerProvider, RouteAware {
  Ticker? _glowTicker;
  AppLifecycleListener? _lifecycleListener;
  bool _appVisible = true;
  bool _routeVisible = true;
  ModalRoute<void>? _subscribedRoute;

  /// Override to return [liquidGlowRouteObserver] to enable route-aware
  /// pausing. Defaults to `null` (route coverage is ignored).
  RouteObserver<ModalRoute<void>>? get routeObserver => null;

  /// Called once per animation frame while [shouldAnimate] is true.
  void onGlowTick(Duration elapsed);

  /// Whether the ticker should currently be producing frames.
  bool get shouldAnimate =>
      _appVisible &&
      _routeVisible &&
      // ignore: deprecated_member_use
      TickerMode.of(context) &&
      !ReduceMotion.of(context);

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onShow: () => _setAppVisible(true),
      onHide: () => _setAppVisible(false),
      onResume: () => _setAppVisible(true),
      onPause: () => _setAppVisible(false),
    );
    _glowTicker = createTicker(_handleTick)..start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final observer = routeObserver;
    final route = ModalRoute.of(context);
    if (observer != null && route != null && route != _subscribedRoute) {
      if (_subscribedRoute != null) {
        observer.unsubscribe(this);
      }
      observer.subscribe(this, route);
      _subscribedRoute = route;
    }
  }

  void _handleTick(Duration elapsed) {
    if (shouldAnimate) {
      onGlowTick(elapsed);
    }
  }

  void _setAppVisible(bool visible) {
    if (_appVisible == visible) return;
    setState(() => _appVisible = visible);
  }

  @override
  void didPushNext() => setState(() => _routeVisible = false);

  @override
  void didPopNext() => setState(() => _routeVisible = true);

  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void dispose() {
    if (_subscribedRoute != null) {
      routeObserver?.unsubscribe(this);
    }
    _lifecycleListener?.dispose();
    _glowTicker?.dispose();
    super.dispose();
  }
}
