/// One edge of a [SiriGlowEdge]'s bounding rect.
enum GlowEdge { top, right, bottom, left }

/// Selects which edges of a [SiriGlowEdge] render the glow. Combine presets
/// with `|`, e.g. `GlowEdgeMask.top | GlowEdgeMask.bottom`.
class GlowEdgeMask {
  const GlowEdgeMask(this.edges);

  static const GlowEdgeMask all = GlowEdgeMask(
    {GlowEdge.top, GlowEdge.right, GlowEdge.bottom, GlowEdge.left},
  );
  static const GlowEdgeMask top = GlowEdgeMask({GlowEdge.top});
  static const GlowEdgeMask right = GlowEdgeMask({GlowEdge.right});
  static const GlowEdgeMask bottom = GlowEdgeMask({GlowEdge.bottom});
  static const GlowEdgeMask left = GlowEdgeMask({GlowEdge.left});

  final Set<GlowEdge> edges;

  bool get showsTop => edges.contains(GlowEdge.top);
  bool get showsRight => edges.contains(GlowEdge.right);
  bool get showsBottom => edges.contains(GlowEdge.bottom);
  bool get showsLeft => edges.contains(GlowEdge.left);

  GlowEdgeMask operator |(GlowEdgeMask other) =>
      GlowEdgeMask({...edges, ...other.edges});

  @override
  bool operator ==(Object other) =>
      other is GlowEdgeMask &&
      other.edges.length == edges.length &&
      other.edges.containsAll(edges);

  @override
  int get hashCode => Object.hashAllUnordered(edges);
}
