import 'package:flutter/widgets.dart';

/// Reads the OS-level "Reduce Motion" accessibility setting.
///
/// Widgets in this package use this instead of ticking when the user has
/// requested reduced motion, freezing on a single static frame.
class ReduceMotion {
  const ReduceMotion._();

  static bool of(BuildContext context) =>
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
}
