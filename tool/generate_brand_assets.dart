// Generates the original GridPop brand assets with pure Dart (no packages):
//
//   dart run tool/generate_brand_assets.dart
//
// Outputs:
//   web/icons/Icon-192.png, Icon-512.png, maskable variants, favicon.png
//   android/ios launcher icons in every density
//   build/branding/icon-grid.png           (the mark on a transparent field)
//   build/branding/piece-sheet.png         (every shape, transparent background)
//
// The mark is drawn from the same recipe as the in-game block painter: a soft
// 3D lip, a vertical gradient face, a top-left gloss and a bottom shade.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

// --- palette (mirrors lib/core/theme/piece_palette.dart) -------------------

class Rgb {
  const Rgb(this.r, this.g, this.b);

  final double r;
  final double g;
  final double b;

  List<int> toBytes() => <int>[
        (r.clamp(0.0, 1.0) * 255).round(),
        (g.clamp(0.0, 1.0) * 255).round(),
        (b.clamp(0.0, 1.0) * 255).round(),
      ];

  Rgb mix(Rgb other, double t) => Rgb(
        r + (other.r - r) * t,
        g + (other.g - g) * t,
        b + (other.b - b) * t,
      );

  Rgb withAlpha(double a) => Rgb(r * a, g * a, b * a);

  static Rgb hex(int value) => Rgb(
        ((value >> 16) & 0xFF) / 255,
        ((value >> 8) & 0xFF) / 255,
        (value & 0xFF) / 255,
      );
}

final Rgb kWhite = Rgb(1, 1, 1);
final Rgb kBlack = Rgb(0, 0, 0);

class BlockPalette {
  const BlockPalette(this.base, this.light, this.dark);

  final Rgb base;
  final Rgb light;
  final Rgb dark;

  static final BlockPalette grape = BlockPalette(
    Rgb.hex(0x8B6BF5),
    Rgb.hex(0xBBA4FF),
    Rgb.hex(0x5F3FC9),
  );
  static final BlockPalette sky = BlockPalette(
    Rgb.hex(0x3FBDF5),
    Rgb.hex(0x8CD8FF),
    Rgb.hex(0x1785BC),
  );
  static final BlockPalette coral = BlockPalette(
    Rgb.hex(0xFF6F6F),
    Rgb.hex(0xFFA0A0),
    Rgb.hex(0xD64646),
  );
  static final BlockPalette mint = BlockPalette(
    Rgb.hex(0x2FD6A8),
    Rgb.hex(0x7FEBCB),
    Rgb.hex(0x12A07C),
  );
  static final BlockPalette sunbeam = BlockPalette(
    Rgb.hex(0xFFD34E),
    Rgb.hex(0xFFE79B),
    Rgb.hex(0xDFA72A),
  );
  static final BlockPalette bubblegum = BlockPalette(
    Rgb.hex(0xFF6FBE),
    Rgb.hex(0xFFA8DC),
    Rgb.hex(0xD34A96),
  );
  static final BlockPalette tangerine = BlockPalette(
    Rgb.hex(0xFF9A3C),
    Rgb.hex(0xFFC079),
    Rgb.hex(0xDE6B1B),
  );
  static final BlockPalette lime = BlockPalette(
    Rgb.hex(0x7ED957),
    Rgb.hex(0xB2EE96),
    Rgb.hex(0x4FA83A),
  );

  static final List<BlockPalette> all = <BlockPalette>[
    grape,
    sky,
    coral,
    mint,
    sunbeam,
    bubblegum,
    tangerine,
    lime,
  ];
}

final Rgb kIndigo = Rgb.hex(0x4B3FD6);
final Rgb kViolet = Rgb.hex(0x7A3FF0);
final Rgb kMagenta = Rgb.hex(0xE64FA6);

// --- tiny raster canvas ----------------------------------------------------

class Canvas {
  Canvas(this.size)
      : pixels = Float32List(size.width * size.height * 3),
        coverage = Float32List(size.width * size.height);

  final _Size size;
  final Float32List pixels;
  final Float32List coverage;

  int get width => size.width;

  int get height => size.height;

  void blend(int x, int y, Rgb color, double alpha) {
    if (x < 0 || y < 0 || x >= width || y >= height || alpha <= 0) {
      return;
    }
    final int index = y * width + x;
    final double dstA = coverage[index];
    final double srcA = alpha.clamp(0.0, 1.0);
    // Straight source-over compositing.
    final double outA = srcA + dstA * (1 - srcA);
    if (outA <= 0) {
      return;
    }
    final int p = index * 3;
    for (int c = 0; c < 3; c++) {
      final double src = c == 0
          ? color.r
          : c == 1
              ? color.g
              : color.b;
      final double dst = pixels[p + c];
      pixels[p + c] = (src * srcA + dst * dstA * (1 - srcA)) / outA;
    }
    coverage[index] = outA;
  }

  /// Fills a rounded rectangle with an optional vertical gradient.
  void fillRRect(
    double left,
    double top,
    double w,
    double h,
    double radius,
    Rgb Function(double t) color, {
    double alpha = 1,
  }) {
    final int x0 = math.max(0, left.floor() - 1);
    final int y0 = math.max(0, top.floor() - 1);
    final int x1 = math.min(width - 1, (left + w).ceil() + 1);
    final int y1 = math.min(height - 1, (top + h).ceil() + 1);

    for (int y = y0; y <= y1; y++) {
      for (int x = x0; x <= x1; x++) {
        final double px = x + 0.5;
        final double py = y + 0.5;
        final double cover = _rrectCoverage(
          px - left,
          py - top,
          w,
          h,
          radius,
        );
        if (cover <= 0) {
          continue;
        }
        final double t = h <= 0 ? 0 : ((py - top) / h).clamp(0.0, 1.0);
        blend(x, y, color(t), cover * alpha);
      }
    }
  }

  void fillCircle(double cx, double cy, double radius, Rgb color,
      {double alpha = 1}) {
    fillRRect(
      cx - radius,
      cy - radius,
      radius * 2,
      radius * 2,
      radius,
      (_) => color,
      alpha: alpha,
    );
  }

  /// Anti-aliased rounded rectangle coverage with cheap 3x3 supersampling.
  double _rrectCoverage(double x, double y, double w, double h, double r) {
    if (x < 0 || y < 0 || x > w || y > h) {
      return 0;
    }
    final double rr = math.min(r, math.min(w, h) / 2);
    if (rr <= 0) {
      return 1;
    }
    // Distance to the rounded corner region.
    final double cx = x.clamp(rr, w - rr);
    final double cy = y.clamp(rr, h - rr);
    final double dx = x - cx;
    final double dy = y - cy;
    final double distance = math.sqrt(dx * dx + dy * dy);
    if (distance <= rr - 0.5) {
      return 1;
    }
    if (distance >= rr + 0.5) {
      return 0;
    }
    return (rr + 0.5 - distance).clamp(0.0, 1.0);
  }

  Uint8List toRgbaBytes() {
    final Uint8List out = Uint8List(width * height * 4);
    for (int i = 0; i < width * height; i++) {
      final double a = coverage[i].clamp(0.0, 1.0);
      final int p = i * 3;
      out[i * 4] = (pixels[p].clamp(0.0, 1.0) * 255).round();
      out[i * 4 + 1] = (pixels[p + 1].clamp(0.0, 1.0) * 255).round();
      out[i * 4 + 2] = (pixels[p + 2].clamp(0.0, 1.0) * 255).round();
      out[i * 4 + 3] = (a * 255).round();
    }
    return out;
  }
}

class _Size {
  const _Size(this.width, this.height);

  final int width;
  final int height;
}

// --- drawing recipes -------------------------------------------------------

/// One soft 3D block, identical in spirit to `BlockPainter` in the game:
/// lip, three stop gradient face, diagonal specular sweep, gloss and shade.
void drawBlock(
  Canvas canvas,
  double left,
  double top,
  double size,
  BlockPalette palette,
) {
  final double radius = size * 0.26;
  final double lip = size * 0.085;

  // Lip (thickness).
  canvas.fillRRect(
    left,
    top + lip,
    size,
    size - lip,
    radius,
    (_) => palette.dark.mix(kBlack, 0.12),
  );

  // Face: light top, base middle, slightly darker bottom.
  final double faceHeight = size - lip * 0.6;
  canvas.fillRRect(
    left,
    top,
    size,
    faceHeight,
    radius,
    (double t) => t < 0.55
        ? palette.light.mix(palette.base, t / 0.55)
        : palette.base.mix(palette.dark, (t - 0.55) / 0.45 * 0.22),
  );

  // Diagonal specular sweep.
  canvas.fillRRect(
    left - size * 0.10,
    top + size * 0.06,
    size * 0.52,
    size * 0.30,
    size * 0.30,
    (_) => kWhite,
    alpha: 0.29,
  );

  // Top-left gloss.
  canvas.fillRRect(
    left + size * 0.12,
    top + size * 0.09,
    size * 0.52,
    size * 0.18,
    size * 0.13,
    (_) => kWhite,
    alpha: 0.30,
  );

  // Bottom shade.
  canvas.fillRRect(
    left + size * 0.10,
    top + size * 0.66,
    size * 0.76,
    size * 0.20,
    size * 0.10,
    (_) => palette.dark,
    alpha: 0.22,
  );
}

/// The GridPop mark: a 2x2 cluster plus one block popping out of the grid.
void drawMark(Canvas canvas, double size, {bool background = true}) {
  if (background) {
    // Aurora gradient plate with rounded corners.
    canvas.fillRRect(
      0,
      0,
      size,
      size,
      size * 0.22,
      (double t) => kIndigo.mix(kViolet, math.min(1, t * 1.4)),
    );
    canvas.fillCircle(
      size * 0.78,
      size * 0.24,
      size * 0.42,
      kMagenta,
      alpha: 0.30,
    );
  }

  final double unit = size * 0.245;
  final double gap = unit * 0.08;
  final double popDx = unit * 0.60;
  final double popDy = -unit * 0.60;

  // Bounding box of cluster + popped block, centred on the canvas.
  final double contentWidth = unit * 2 + gap + popDx;
  final double contentHeight = unit * 2 + gap;
  final double left = (size - contentWidth) / 2;
  final double top = (size - contentHeight) / 2;

  void blockAt(double x, double y, BlockPalette palette) {
    // Tight drop shadow, shared by every block for a consistent silhouette.
    canvas.fillRRect(
      x + unit * 0.06,
      y + unit * 0.10,
      unit,
      unit,
      unit * 0.26,
      (_) => kBlack,
      alpha: 0.20,
    );
    drawBlock(canvas, x, y, unit, palette);
  }

  blockAt(left + unit + gap, top, BlockPalette.sky);
  blockAt(left, top + unit + gap, BlockPalette.mint);
  blockAt(left, top, BlockPalette.grape);
  blockAt(
    left + unit + gap + popDx,
    top + unit + gap + popDy,
    BlockPalette.sunbeam,
  );
}

/// Shape list of the game (kept in sync with `PieceCatalog`).
final List<List<List<int>>> kShapes = <List<List<int>>>[
  <List<int>>[
    <int>[0, 0],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[2, 0],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[1, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[0, 3],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[2, 0],
    <int>[3, 0],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[1, 0],
    <int>[1, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[1, 1],
    <int>[1, 2],
  ],
  <List<int>>[
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 0],
    <int>[1, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[2, 0],
    <int>[2, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[0, 3],
    <int>[1, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 0],
    <int>[2, 0],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 1],
    <int>[2, 1],
  ],
  <List<int>>[
    <int>[0, 1],
    <int>[1, 0],
    <int>[1, 1],
    <int>[1, 2],
    <int>[2, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 2],
    <int>[1, 0],
    <int>[1, 1],
    <int>[1, 2],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[1, 1],
    <int>[1, 2],
    <int>[2, 2],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[1, 1],
    <int>[2, 1],
    <int>[3, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[1, 0],
    <int>[1, 1],
    <int>[2, 0],
    <int>[2, 1],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[1, 1],
    <int>[1, 2],
    <int>[2, 2],
    <int>[2, 3],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 0],
    <int>[1, 2],
    <int>[2, 0],
    <int>[2, 2],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[1, 0],
    <int>[1, 1],
    <int>[2, 1],
    <int>[2, 2],
    <int>[3, 2],
    <int>[3, 3],
  ],
  <List<int>>[
    <int>[0, 0],
    <int>[0, 1],
    <int>[0, 2],
    <int>[1, 1],
    <int>[2, 0],
    <int>[2, 1],
    <int>[2, 2],
  ],
  <List<int>>[
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
];

/// Contact sheet of every shape on a transparent background.
void drawPieceSheet(Canvas canvas, double size) {
  const int columns = 7;
  final double padding = size * 0.018;
  final double step = (size - padding * (columns + 1)) / columns;
  final double tileSize = step - padding;

  for (int i = 0; i < kShapes.length; i++) {
    final int col = i % columns;
    final int row = i ~/ columns;
    final double tileLeft = padding + col * step;
    final double tileTop = padding + row * step;

    final List<List<int>> cells = kShapes[i];
    var maxRow = 0;
    var maxCol = 0;
    for (final List<int> cell in cells) {
      if (cell[0] > maxRow) maxRow = cell[0];
      if (cell[1] > maxCol) maxCol = cell[1];
    }
    final double block = math.min(
      tileSize * 0.74 / (maxRow + 1),
      tileSize * 0.74 / (maxCol + 1),
    );
    final double originX =
        tileLeft + (tileSize - block * (maxCol + 1)) / 2;
    final double originY =
        tileTop + (tileSize - block * (maxRow + 1)) / 2;
    final BlockPalette palette = BlockPalette.all[i % BlockPalette.all.length];

    for (final List<int> cell in cells) {
      drawBlock(
        canvas,
        originX + cell[1] * block,
        originY + cell[0] * block,
        block,
        palette,
      );
    }
  }
}

// --- PNG encoding ----------------------------------------------------------

void writePng(String path, Canvas canvas) {
  final Uint8List rgba = canvas.toRgbaBytes();
  final BytesBuilder builder = BytesBuilder();

  // Signature + IHDR
  builder.add(<int>[137, 80, 78, 71, 13, 10, 26, 10]);
  final ByteData header = ByteData(13);
  header.setUint32(0, canvas.width);
  header.setUint32(4, canvas.height);
  header.setUint8(8, 8); // bit depth
  header.setUint8(9, 6); // colour type RGBA
  header.setUint8(10, 0);
  header.setUint8(11, 0);
  header.setUint8(12, 0);
  _chunk(builder, 'IHDR', header.buffer.asUint8List());

  // Raw scanlines with filter byte 0.
  final BytesBuilder raw = BytesBuilder();
  for (int y = 0; y < canvas.height; y++) {
    raw.addByte(0);
    final int start = y * canvas.width * 4;
    raw.add(
      rgba.sublist(start, start + canvas.width * 4),
    );
  }
  _chunk(builder, 'IDAT', ZLibEncoder(level: 9).convert(raw.takeBytes()));
  _chunk(builder, 'IEND', const <int>[]);

  final File file = File(path);
  file.parent.createSync(recursive: true);
  file.writeAsBytesSync(builder.takeBytes());
  // ignore: avoid_print
  print('  wrote ${file.path} (${canvas.width}x${canvas.height})');
}

void _chunk(BytesBuilder builder, String type, List<int> data) {
  final ByteData length = ByteData(4)..setUint32(0, data.length);
  builder.add(length.buffer.asUint8List());
  final List<int> typeBytes = type.codeUnits;
  builder.add(typeBytes);
  builder.add(data);
  final int crc = _crc32(<int>[...typeBytes, ...data]);
  final ByteData crcData = ByteData(4)..setUint32(0, crc);
  builder.add(crcData.buffer.asUint8List());
}

int _crc32(List<int> bytes) {
  int crc = 0xFFFFFFFF;
  for (final int byte in bytes) {
    crc ^= byte;
    for (int i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

// --- entry point -----------------------------------------------------------

Canvas renderIcon(int size, {bool background = true}) {
  final Canvas canvas = Canvas(_Size(size, size));
  drawMark(canvas, size.toDouble(), background: background);
  return canvas;
}

/// Maskable icons need the mark inside the safe zone (80% of the canvas).
Canvas renderMaskable(int size) {
  final Canvas canvas = Canvas(_Size(size, size));
  canvas.fillRRect(
    0,
    0,
    size.toDouble(),
    size.toDouble(),
    0,
    (_) => kIndigo.mix(kViolet, 0.4),
  );
  final Canvas inner = renderIcon(size, background: false);
  final double scale = size * 0.62;
  final double offset = (size - scale) / 2;
  _blit(canvas, inner, offset, offset, scale);
  return canvas;
}

void _blit(Canvas target, Canvas source, double dx, double dy, double scale) {
  final int sw = source.width;
  final int sh = source.height;
  final double sxStep = sw / (scale);
  final double syStep = sh / (scale);
  for (int y = 0; y < scale.round(); y++) {
    for (int x = 0; x < scale.round(); x++) {
      final int sxp = (x * sxStep).floor().clamp(0, sw - 1);
      final int syp = (y * syStep).floor().clamp(0, sh - 1);
      final int si = syp * sw + sxp;
      final double alpha = source.coverage[si];
      if (alpha <= 0) continue;
      final int p = si * 3;
      target.blend(
        (dx + x).floor(),
        (dy + y).floor(),
        Rgb(source.pixels[p], source.pixels[p + 1], source.pixels[p + 2]),
        alpha,
      );
    }
  }
}

void main() {
  // ignore: avoid_print
  print('GridPop brand assets');

  // ignore: avoid_print
  print('web icons');
  writePng('web/icons/Icon-192.png', renderIcon(192));
  writePng('web/icons/Icon-512.png', renderIcon(512));
  writePng('web/icons/Icon-maskable-192.png', renderMaskable(192));
  writePng('web/icons/Icon-maskable-512.png', renderMaskable(512));
  writePng('web/favicon.png', renderIcon(64));

  // Android launcher icons.
  const Map<String, int> androidDensities = <String, int>{
    'android/app/src/main/res/mipmap-mdpi': 48,
    'android/app/src/main/res/mipmap-hdpi': 72,
    'android/app/src/main/res/mipmap-xhdpi': 96,
    'android/app/src/main/res/mipmap-xxhdpi': 144,
    'android/app/src/main/res/mipmap-xxxhdpi': 192,
  };
  // ignore: avoid_print
  print('android launcher icons');
  androidDensities.forEach((String path, int size) {
    writePng('$path/ic_launcher.png', renderIcon(size));
  });

  // iOS launcher icons.
  const Map<String, int> iosSizes = <String, int>{
    'ios/Runner/Assets.xcassets/AppIcon.appiconset': 1024,
  };
  // ignore: avoid_print
  print('ios app icon');
  iosSizes.forEach((String path, int size) {
    writePng('$path/icon-1024.png', renderIcon(size));
  });

  // Design references.
  // ignore: avoid_print
  print('design references');
  writePng('build/branding/icon-grid.png', renderIcon(512));
  writePng('build/branding/icon-transparent.png',
      renderIcon(512, background: false));

  final int rows = (kShapes.length / 7).ceil();
  final Canvas sheet = Canvas(_Size(1400, 1400));
  drawPieceSheet(sheet, 1400);
  writePng('build/branding/piece-sheet.png', sheet);
  // ignore: avoid_print
  print('  shape sheet rows: $rows');

  // ignore: avoid_print
  print('done');
}
