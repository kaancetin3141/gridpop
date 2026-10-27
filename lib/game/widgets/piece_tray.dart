import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/piece_palette.dart';
import '../models/piece_slot.dart';
import '../services/game_controller.dart';
import 'painting/piece_preview_painter.dart';

/// The row of pieces the player can pick up.
///
/// The tray only *renders*: pointer handling lives in the parent
/// [GameBoardView] so mouse and touch share exactly one code path.
///
/// A used slot stays empty (and shows a dashed placeholder) until every piece
/// of the batch has been played: then all three slots refill at once.
class PieceTray extends StatelessWidget {
  const PieceTray({
    super.key,
    required this.controller,
    required this.slotKeys,
    this.highlightedSlot,
    this.dimmedSlot,
    this.vertical = false,
    this.locked = false,
  });

  final GameController controller;

  /// One [GlobalKey] per slot, used for hit testing during a drag.
  final List<GlobalKey> slotKeys;

  /// Slot highlighted by the hint button.
  final int? highlightedSlot;

  /// Slot currently being dragged (dimmed while it follows the pointer).
  final int? dimmedSlot;

  /// Lays the pieces out in a column (landscape) instead of a row.
  final bool vertical;

  /// True while the previous piece is still settling.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<PieceSlot?> tray = controller.state.tray;

    final List<Widget> slots = <Widget>[
      for (int i = 0; i < tray.length; i++)
        Expanded(
          child: _TraySlot(
            key: slotKeys[i],
            slot: tray[i],
            index: i,
            palette: palette,
            highlighted: highlightedSlot == i,
            dimmed: dimmedSlot == i,
            spent: locked,
            repaint: controller,
          ),
        ),
    ];

    if (vertical) {
      return Column(
        children: <Widget>[
          for (int i = 0; i < slots.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(height: 12),
            slots[i],
          ],
        ],
      );
    }

    // A soft shelf holds the three slots, so the tray reads as one designed
    // dock instead of three floating cards.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: palette.surface.withOpacity(palette.isDark ? 0.06 : 0.55),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: palette.outline.withOpacity(palette.isDark ? 0.35 : 0.6),
        ),
        boxShadow: AppShadows.soft(
          palette.isDark ? Colors.black : AppColors.indigo,
          strength: 0.35,
        ),
      ),
      child: Row(
        children: <Widget>[
          for (int i = 0; i < slots.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 10),
            slots[i],
          ],
        ],
      ),
    );
  }
}

class _TraySlot extends StatelessWidget {
  const _TraySlot({
    super.key,
    required this.slot,
    required this.index,
    required this.palette,
    required this.highlighted,
    required this.dimmed,
    required this.spent,
    required this.repaint,
  });

  /// `null` when the slot has been used and waits for the batch refill.
  final PieceSlot? slot;

  final int index;
  final AppPalette palette;
  final bool highlighted;
  final bool dimmed;
  final bool spent;
  final Listenable repaint;

  @override
  Widget build(BuildContext context) {
    if (slot == null) {
      return AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: TraySlotPainter(
            fill: palette.cell.withOpacity(0.45),
            border: palette.outline.withOpacity(0.5),
            radius: AppRadius.lg,
            glow: Colors.transparent,
            glowStrength: 0,
            dashed: true,
          ),
          child: Center(
            child: Icon(
              Icons.add_rounded,
              size: 22,
              color: palette.textMuted.withOpacity(0.35),
            ),
          ),
        ),
      );
    }

    final PieceColor color = PiecePalette.byIndex(slot!.colorIndex);
    final bool inactive = dimmed || spent;

    return TweenAnimationBuilder<double>(
      // `token` changes on every batch refill and `rotation` on every rotate:
      // both play the same short pop, which keeps the tray lively.
      key: ValueKey<String>('${slot!.token}-${slot!.rotation}'),
      tween: Tween<double>(begin: 0.86, end: 1),
      duration: Duration(
        milliseconds: MotionConfig.trayNewPiece + index * 40,
      ),
      curve: Curves.easeOutBack,
      builder: (BuildContext context, double scale, Widget? child) {
        return Transform.scale(scale: scale, child: child);
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: CustomPaint(
          painter: TraySlotPainter(
            fill: spent ? palette.cell : palette.surfaceAlt,
            border: highlighted
                ? color.base.withOpacity(0.9)
                : palette.outline.withOpacity(palette.isDark ? 0.6 : 0.9),
            radius: AppRadius.lg,
            glow: color.base,
            glowStrength: highlighted ? 1 : 0,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: CustomPaint(
              painter: PiecePreviewPainter(
                slot: slot!,
                maxCell: 84,
                opacity: inactive ? 0.28 : 1,
                repaint: repaint,
              ),
            ),
          ),
        ),
      ),
    );
  }
}