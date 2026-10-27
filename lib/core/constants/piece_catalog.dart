/// The complete, original shape library of GridPop.
///
/// Every shape is authored here as a list of `[row, column]` coordinates in its
/// canonical orientation. [PieceShape] turns them into rotatable models at
/// runtime, so a single definition covers all four orientations.
///
/// The set is deliberately built from small, distinct silhouettes and it is
/// 100% owned by GridPop: no external game asset, pattern or naming was used.
library;

/// Blueprint (pure data) of one puzzle shape.
class PieceBlueprint {
  const PieceBlueprint({
    required this.id,
    required this.labelKey,
    required this.cells,
    required this.weight,
    this.tier = 1,
  });

  /// Stable identifier, also used by tests and by the How To Play gallery.
  final String id;

  /// Localization key used for the display name.
  final String labelKey;

  /// Cells of the canonical orientation as `[row, column]` pairs.
  final List<List<int>> cells;

  /// Relative spawn weight.
  final double weight;

  /// Difficulty tier (1 easy, 2 medium, 3 hard). The generator uses it to
  /// widen the pool of large pieces as the session progresses.
  final int tier;

  /// Number of cells in the canonical orientation.
  int get cellCount => cells.length;
}

/// Static catalogue of every shape in the game.
class PieceCatalog {
  const PieceCatalog._();

  // --- 1 cell -----------------------------------------------------------
  static const PieceBlueprint dot = PieceBlueprint(
    id: 'dot',
    labelKey: 'piece.dot',
    cells: <List<int>>[
      <int>[0, 0],
    ],
    weight: 9,
  );

  // --- 2 cells ----------------------------------------------------------
  static const PieceBlueprint dom = PieceBlueprint(
    id: 'dom',
    labelKey: 'piece.dom',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
    ],
    weight: 10,
  );

  static const PieceBlueprint riser = PieceBlueprint(
    id: 'riser',
    labelKey: 'piece.riser',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
    ],
    weight: 10,
  );

  // --- 3 cells ----------------------------------------------------------
  static const PieceBlueprint bar = PieceBlueprint(
    id: 'bar',
    labelKey: 'piece.bar',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
    ],
    weight: 10,
  );

  static const PieceBlueprint stalk = PieceBlueprint(
    id: 'stalk',
    labelKey: 'piece.stalk',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[2, 0],
    ],
    weight: 10,
  );

  static const PieceBlueprint elbow = PieceBlueprint(
    id: 'elbow',
    labelKey: 'piece.elbow',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[1, 1],
    ],
    weight: 8,
  );

  // --- 4 cells ----------------------------------------------------------
  static const PieceBlueprint rail = PieceBlueprint(
    id: 'rail',
    labelKey: 'piece.rail',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
    ],
    weight: 7,
  );

  static const PieceBlueprint tower = PieceBlueprint(
    id: 'tower',
    labelKey: 'piece.tower',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[2, 0],
      <int>[3, 0],
    ],
    weight: 7,
  );

  static const PieceBlueprint block = PieceBlueprint(
    id: 'block',
    labelKey: 'piece.block',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[1, 0],
      <int>[1, 1],
    ],
    weight: 7,
  );

  static const PieceBlueprint tee = PieceBlueprint(
    id: 'tee',
    labelKey: 'piece.tee',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 1],
    ],
    weight: 6,
    tier: 2,
  );

  static const PieceBlueprint zigzag = PieceBlueprint(
    id: 'zigzag',
    labelKey: 'piece.zigzag',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[1, 1],
      <int>[1, 2],
    ],
    weight: 6,
    tier: 2,
  );

  static const PieceBlueprint zigzagFlip = PieceBlueprint(
    id: 'zigzagFlip',
    labelKey: 'piece.zigzagFlip',
    cells: <List<int>>[
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 0],
      <int>[1, 1],
    ],
    weight: 6,
    tier: 2,
  );

  static const PieceBlueprint hook = PieceBlueprint(
    id: 'hook',
    labelKey: 'piece.hook',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[2, 0],
      <int>[2, 1],
    ],
    weight: 6,
    tier: 2,
  );

  // --- 5 cells ----------------------------------------------------------
  static const PieceBlueprint beam = PieceBlueprint(
    id: 'beam',
    labelKey: 'piece.beam',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
      <int>[0, 4],
    ],
    weight: 3.4,
    tier: 2,
  );

  static const PieceBlueprint spire = PieceBlueprint(
    id: 'spire',
    labelKey: 'piece.spire',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[2, 0],
      <int>[3, 0],
      <int>[4, 0],
    ],
    weight: 3.4,
    tier: 2,
  );

  static const PieceBlueprint teeLong = PieceBlueprint(
    id: 'teeLong',
    labelKey: 'piece.teeLong',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[0, 3],
      <int>[1, 1],
    ],
    weight: 3.2,
    tier: 2,
  );

  static const PieceBlueprint corner = PieceBlueprint(
    id: 'corner',
    labelKey: 'piece.corner',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 0],
      <int>[2, 0],
    ],
    weight: 3,
    tier: 2,
  );

  static const PieceBlueprint plus = PieceBlueprint(
    id: 'plus',
    labelKey: 'piece.plus',
    cells: <List<int>>[
      <int>[0, 1],
      <int>[1, 0],
      <int>[1, 1],
      <int>[1, 2],
      <int>[2, 1],
    ],
    weight: 2.6,
    tier: 3,
  );

  static const PieceBlueprint crown = PieceBlueprint(
    id: 'crown',
    labelKey: 'piece.crown',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 2],
      <int>[1, 0],
      <int>[1, 1],
      <int>[1, 2],
    ],
    weight: 2.4,
    tier: 3,
  );

  static const PieceBlueprint bolt = PieceBlueprint(
    id: 'bolt',
    labelKey: 'piece.bolt',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[1, 1],
      <int>[1, 2],
      <int>[2, 2],
    ],
    weight: 2.4,
    tier: 3,
  );

  static const PieceBlueprint fin = PieceBlueprint(
    id: 'fin',
    labelKey: 'piece.fin',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[1, 1],
      <int>[2, 1],
      <int>[3, 1],
    ],
    weight: 2,
    tier: 3,
  );

  // --- 6 and 7 cells ----------------------------------------------------
  static const PieceBlueprint terrace = PieceBlueprint(
    id: 'terrace',
    labelKey: 'piece.terrace',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[1, 0],
      <int>[1, 1],
      <int>[2, 0],
      <int>[2, 1],
    ],
    weight: 3,
    tier: 2,
  );

  static const PieceBlueprint stairs = PieceBlueprint(
    id: 'stairs',
    labelKey: 'piece.stairs',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[1, 1],
      <int>[1, 2],
      <int>[2, 2],
      <int>[2, 3],
    ],
    weight: 1.8,
    tier: 3,
  );

  static const PieceBlueprint gate = PieceBlueprint(
    id: 'gate',
    labelKey: 'piece.gate',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 0],
      <int>[1, 2],
      <int>[2, 0],
      <int>[2, 2],
    ],
    weight: 1.2,
    tier: 3,
  );

  static const PieceBlueprint arrow = PieceBlueprint(
    id: 'arrow',
    labelKey: 'piece.arrow',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[1, 0],
      <int>[1, 1],
      <int>[2, 1],
      <int>[2, 2],
      <int>[3, 2],
      <int>[3, 3],
    ],
    weight: 1,
    tier: 3,
  );

  static const PieceBlueprint monolith = PieceBlueprint(
    id: 'monolith',
    labelKey: 'piece.monolith',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 1],
      <int>[2, 0],
      <int>[2, 1],
      <int>[2, 2],
    ],
    weight: 0.9,
    tier: 3,
  );

  static const PieceBlueprint tile = PieceBlueprint(
    id: 'tile',
    labelKey: 'piece.tile',
    cells: <List<int>>[
      <int>[0, 0],
      <int>[0, 1],
      <int>[0, 2],
      <int>[1, 0],
      <int>[1, 1],
      <int>[1, 2],
      <int>[2, 0],
      <int>[2, 1],
      <int>[2, 2],
    ],
    weight: 1.4,
    tier: 3,
  );

  /// Every shape, ordered from most common to rarest.
  static const List<PieceBlueprint> all = <PieceBlueprint>[
    dot,
    dom,
    riser,
    bar,
    stalk,
    elbow,
    rail,
    tower,
    block,
    tee,
    zigzag,
    zigzagFlip,
    hook,
    beam,
    spire,
    teeLong,
    corner,
    terrace,
    plus,
    crown,
    bolt,
    fin,
    stairs,
    gate,
    arrow,
    monolith,
    tile,
  ];

  /// Human readable fallback order for the shape gallery.
  static PieceBlueprint? byId(String id) {
    for (final PieceBlueprint piece in all) {
      if (piece.id == id) {
        return piece;
      }
    }
    return null;
  }
}