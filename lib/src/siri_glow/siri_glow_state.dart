/// The current intonation mode of a [SiriGlowEdge].
enum SiriGlowState {
  /// Gentle, slow edge rotation.
  idle,

  /// Pulsating intonation.
  listening,

  /// Faster color cycling.
  thinking,

  /// High-intensity wave patterns.
  speaking,
}
