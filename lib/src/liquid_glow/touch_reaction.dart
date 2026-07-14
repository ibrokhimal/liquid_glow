import 'package:flutter/painting.dart';

/// The current touch-reaction bump state for [LiquidGlow]: a position
/// (normalized 0..1 in the widget's local bounds), a strength, and an age
/// in seconds since the touch began (used by the shader to decay the bump).
class TouchReactionState {
  const TouchReactionState({
    required this.position,
    required this.strength,
    required this.age,
  });

  factory TouchReactionState.none() =>
      const TouchReactionState(position: Offset.zero, strength: 0, age: 999);

  final Offset position;
  final double strength;
  final double age;

  @override
  bool operator ==(Object other) =>
      other is TouchReactionState &&
      other.position == position &&
      other.strength == strength &&
      other.age == age;

  @override
  int get hashCode => Object.hash(position, strength, age);
}
