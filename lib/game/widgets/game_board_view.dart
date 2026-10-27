import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/piece_palette.dart';
import '../../../core/utils/grid_geometry.dart';
import '../../../core/utils/responsive.dart';
import '../logic/board_analyzer.dart';
import '../models/game_phase.dart';
import '../models/grid_position.dart';
import '../models/piece_slot.dart';
import '../services/game_controller.dart';
import 'effects/effects_layer.dart';
import 'painting/block_painter.dart';
import 'painting/board_painter.dart';
import 'painting/effects_painter.dart';
import 'piece_tray.dart';

/// Interactive play area: board + tray + drag handling.
///
/// One [Listener] wraps the whole area and does the hit testing by hand, so the
/// exact same code path serves finger drags on mobile and mouse drags on web.
class GameBoardView extends StatefulWidget {
  const GameBoardView({
    super.key,
    required this.controller,
    required this.effects,
    required this.showGhost,
    this.highlightedSlot,
    this.onSettled,
    this.aiming = false,
    this.onCellTap,
  });

  final GameController controller;
  final GameEffects effects;
  final bool showGhost;

  /// Slot highlighted by the hint button, or `null`.
  final int? highlightedSlot;

  /// Fired once every settle animation of the last move is over. This is the
  /// moment the tray is refilled and the input gate reopens.
  final VoidCallback? onSettled;

  /// True while the hammer/bomb waits for a target cell.
  final bool aiming;

  /// Fired when the player taps a cell while [aiming]. The board itself does
  /// not change: the screen decides which power-up to apply.
  final void Function(GridPosition cell)? onCellTap;

  @override
  State<GameBoardView> createState() => GameBoardViewState();
}

/// Public state class so the parent screen can drive the animation ticker
/// through a [GlobalKey].
class GameBoardViewState extends State<GameBoardView>
    with SingleTickerProviderStateMixin {
  final GlobalKey _rootKey = GlobalKey();
  final GlobalKey _boardKey = GlobalKey();
  final List<GlobalKey> _slotKeys = <GlobalKey>[
    GlobalKey(),
    GlobalKey(),
    GlobalKey(),
  ];
  final ValueNotifier<GhostPreview?> _ghost = ValueNotifier<GhostPreview?>(null);
  final ValueNotifier<_DragState?> _drag = ValueNotifier<_DragState?>(null);

  Ticker? _ticker;
  Duration _tickerOrigin = Duration.zero;
  Duration _effectsTime = Duration.zero;
  BoardGeometry _geometry = const BoardGeometry(
    origin: Offset.zero,
    cellSize: 1,
    gap: 0,
    rows: 8,
    columns: 8,
  );

  int? _pressedSlot;
  Offset? _pressedPosition;
  bool _isDragging = false;
  bool _wasSettling = false;

  /// Cell pressed while a smashing power-up is armed.
  GridPosition? _aimCell;
  Offset? _aimOrigin;

  /// Board squash ("juice"): a short scale kick after every placement.
  bool _squash = false;
  bool _kickFired = false;
  Timer? _kickTimer;

  /// Pointer that started before the input gate closed. Kept alive for a short
  /// grace window so a fast player is not punished ("input buffering").
  Offset? _bufferedPress;
  int _bufferedSlot = -1;
  Duration? _bufferedAt;

  /// Honours the platform "reduce motion" setting.
  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  GameController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker?.dispose();
    _ghost.dispose();
    _drag.dispose();
    super.dispose();
  }

void _onTick(Duration elapsed) {
    final Duration now = _tickerOrigin + elapsed;
    _effectsTime = now;

    // Board squash: fires the moment the placed cells start popping in.
    final bool placing = widget.effects.placed.isNotEmpty;
    if (placing && !_kickFired) {
      _kickFired = true;
      if (!_reducedMotion) {
        _kickTimer?.cancel();
        setState(() => _squash = true);
        _kickTimer = Timer(
          const Duration(milliseconds: MotionConfig.boardSquashTime),
          () {
            if (mounted) {
              setState(() => _squash = false);
            }
          },
        );
      }
    } else if (!placing) {
      _kickFired = false;
    }

    final bool stillActive = widget.effects.tick(now);

    // The settle window ends once the freeze frame, the pop-in and the line
    // clear are all done. Only then does the next piece arrive. The check runs
    // after the tick so the very last frame of the animation is not missed.
    if (_wasSettling && !widget.effects.isSettling) {
      _wasSettling = false;
      widget.onSettled?.call();
    } else if (widget.effects.isSettling) {
      _wasSettling = true;
    }

    if (!stillActive && !_wasSettling) {
      _ticker?.stop();
    }
  }

  /// Restarts the animation ticker. Called by the screen right after it fed a
  /// new effect into [GameEffects].
  void ensureAnimating() {
    if (_ticker == null || _ticker!.isActive) {
      return;
    }
    _tickerOrigin = _effectsTime;
    _ticker!.start();
  }

  // --- pointer handling ---------------------------------------------------

  void _onPointerDown(PointerDownEvent event) {
    if (widget.aiming) {
      final (int, int)? cell =
          _geometry.cellAt(_toBoardLocal(event.position));
      _aimCell = cell == null ? null : GridPosition(cell.$1, cell.$2);
      _aimOrigin = event.position;
      _bufferedSlot = -1;
      _bufferedPress = null;
      _bufferedAt = null;
      return;
    }
    final int? slot = _hitTestSlot(event.position);
    if (slot == null || _controller.slotAt(slot) == null) {
      // Used (null) slots are drawn greyed out: pressing one must do nothing.
      return;
    }
    if (!_controller.state.acceptsInput || _controller.inputLocked) {
      // Remember the intent: if the settle window closes within the grace
      // period the drag starts right away instead of being dropped.
      _bufferedSlot = slot;
      _bufferedPress = event.position;
      _bufferedAt = _effectsTime;
      return;
    }
    _pressedSlot = slot;
    _pressedPosition = event.position;
    _isDragging = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pressedSlot == null) {
      _promoteBufferedPress(event.position);
      return;
    }
    if (_pressedPosition == null) {
      return;
    }
    if (!_isDragging &&
        (event.position - _pressedPosition!).distance > InputConfig.dragSlop) {
      _beginDrag(event.position);
    }
    if (_isDragging) {
      _updateDrag(event.position);
    }
  }

  /// Honours a press that happened while the gate was closed.
  void _promoteBufferedPress(Offset position) {
    if (_bufferedSlot < 0 || _bufferedAt == null) {
      return;
    }
    final Duration age = _effectsTime - _bufferedAt!;
    if (age > const Duration(milliseconds: MotionConfig.inputGrace)) {
      _bufferedSlot = -1;
      return;
    }
    if (!_controller.state.acceptsInput || _controller.inputLocked) {
      return;
    }
    _pressedSlot = _bufferedSlot;
    _pressedPosition = _bufferedPress;
    _isDragging = false;
    _bufferedSlot = -1;
    if ((position - (_pressedPosition ?? position)).distance >
        InputConfig.dragSlop) {
      _beginDrag(position);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (widget.aiming) {
      final GridPosition? cell = _aimCell;
      final Offset? origin = _aimOrigin;
      _aimCell = null;
      _aimOrigin = null;
      if (cell != null &&
          (origin == null ||
              (event.position - origin).distance <= InputConfig.dragSlop)) {
        widget.onCellTap?.call(cell);
      }
      return;
    }
    final int? slot = _pressedSlot;
    if (slot == null) {
      // Nothing was picked up: drop any buffered intent so a press made while
      // the gate was closed cannot turn into a drag later.
      _bufferedSlot = -1;
      _bufferedPress = null;
      _bufferedAt = null;
      return;
    }
    if (!_isDragging) {
      // A tap rotates the piece: quick, discoverable and works everywhere.
      _controller.rotateSlot(slot);
      _resetDrag();
      return;
    }

    final GhostPreview? preview = _ghost.value;
    if (preview != null && preview.isValid) {
      _controller.placePiece(slot, preview.topRow, preview.leftCol);
} else {
      // Invalid drop: flash the would-be cells red, then snap back.
      if (preview != null) {
        widget.effects.onInvalidDrop(<GridPosition>[
          for (final GridPosition cell in preview.cells)
            GridPosition(
              cell.row + preview.topRow,
              cell.col + preview.leftCol,
            ),
        ]);
        ensureAnimating();
      }
      // The controller reports the miss and the piece snaps back...
      _controller.placePiece(slot, -1, -1);
      // ...and if nothing in the tray fits any more, the run is over.
      _controller.checkForDeadTray();
    }
    _resetDrag();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _aimCell = null;
    _aimOrigin = null;
    _resetDrag();
  }

  void _beginDrag(Offset pointer) {
    final int? slot = _pressedSlot;
    if (slot == null) {
      return;
    }
    _isDragging = true;
    _controller.playPickupCue();
    _drag.value = _DragState(
      slot: _controller.slotAt(slot),
      pointer: _toBoardLocal(pointer),
      cellSize: _geometry.cellSize,
      lifted: true,
    );
    _updateGhost(pointer);
    if (mounted) {
      setState(() {});
    }
  }

  void _updateDrag(Offset pointer) {
    final _DragState? current = _drag.value;
    if (current == null) {
      return;
    }
    _drag.value = _DragState(
      slot: current.slot,
      pointer: _toBoardLocal(pointer),
      cellSize: _geometry.cellSize,
      lifted: current.lifted,
    );
    _updateGhost(pointer);
  }

  void _updateGhost(Offset pointer) {
    final PieceSlot? slot = _drag.value?.slot;
    if (slot == null || !widget.showGhost) {
      _ghost.value = null;
      return;
    }
    // The geometry lives in the board stack's coordinate space, not in the
    // listener's. Using the wrong origin offsets the preview by the centring
    // margin on wide layouts.
    final (int, int)? cell = _geometry.cellAt(_toBoardLocal(pointer));
    if (cell == null) {
      _ghost.value = null;
      return;
    }
    final GridAnchor? anchor =
        BoardAnalyzer.anchorForDrop(_controller.board, slot, cell.$1, cell.$2);
    if (anchor == null) {
      _ghost.value = null;
      return;
    }
    final bool valid =
        _controller.board.canPlace(slot.cells, anchor.topRow, anchor.leftCol);
    _ghost.value = GhostPreview(
      topRow: anchor.topRow,
      leftCol: anchor.leftCol,
      cells: slot.cells,
      color: PiecePalette.byIndex(slot.colorIndex),
      isValid: valid,
    );
  }

  void _resetDrag() {
    _pressedSlot = null;
    _pressedPosition = null;
    _isDragging = false;
    _bufferedSlot = -1;
    _bufferedPress = null;
    _ghost.value = null;
    _drag.value = null;
    if (mounted) {
      setState(() {});
    }
  }

  int? _hitTestSlot(Offset globalPosition) {
    for (int i = 0; i < _slotKeys.length; i++) {
      final RenderObject? object = _slotKeys[i].currentContext?.findRenderObject();
      if (object is RenderBox && object.hasSize) {
        final Offset local = object.globalToLocal(globalPosition);
        if (local.dx >= 0 &&
            local.dy >= 0 &&
            local.dx <= object.size.width &&
            local.dy <= object.size.height) {
          return i;
        }
      }
    }
    return null;
  }

  /// Metrics of the last layout pass. Exposed for tests that need to aim at
  /// a real cell instead of guessing coordinates.
  BoardGeometry get geometry => _geometry;

  /// Global rectangle of the board stack (the surface the grid is painted on).
  ///
  /// The board is centred inside the listener, so aiming with the listener's
  /// rect would be wrong on wide layouts; tests and overlays should use this.
  Rect? get boardRect {
    final RenderObject? object = _boardKey.currentContext?.findRenderObject();
    if (object is RenderBox && object.hasSize) {
      return object.localToGlobal(Offset.zero) & object.size;
    }
    return null;
  }

  Offset _toLocal(Offset globalPosition) {
    final RenderObject? object = _rootKey.currentContext?.findRenderObject();
    if (object is RenderBox) {
      return object.globalToLocal(globalPosition);
    }
    return globalPosition;
  }

  /// Converts a global pointer into the coordinate space of the board stack,
  /// which is where the lifted piece is painted.
  Offset _toBoardLocal(Offset globalPosition) {
    final RenderObject? object = _boardKey.currentContext?.findRenderObject();
    if (object is RenderBox) {
      return object.globalToLocal(globalPosition);
    }
    return _toLocal(globalPosition);
  }

  // --- build -------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final int size = _controller.board.size;
    const double gap = InputConfig.trayGap;
    final bool paused = _controller.phase == GamePhase.paused;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Size area = Size(constraints.maxWidth, constraints.maxHeight);

        // Landscape phones and short windows cannot afford a tray underneath:
        // the pieces move next to the board instead.
        final bool trayOnSide =
            area.height < Responsive.trayHeight(context) + 160 &&
                area.width >= 520;

        final double panelPadding =
            math.min(20.0, area.shortestSide * 0.045);

        final double trayExtent = trayOnSide
            ? math.min(168.0, area.width * 0.24)
            : math.min(
                Responsive.trayHeight(context),
                math.max(96.0, area.height * 0.26),
              );

        // The board is a square stage: the grid then fills the whole panel and
        // the blocks become as chunky as they should be. Whatever height is
        // left goes to the tray, so its pieces can breathe.
        final double freeHeight = math.max(80.0, area.height - trayExtent - gap);
        final double boardSide = trayOnSide
            ? area.height
            : math.min(area.width, freeHeight);
        final double trayHeight =
            trayOnSide ? trayExtent : area.height - boardSide - gap;

        // The slot cards are square, so the shelf never needs more height than
        // one slot plus its padding. Any extra height becomes symmetric
        // breathing room around the board instead of a hollow card.
        final double slotSide = math.max(0, (area.width - 40) / 3);
        final double dockHeight =
            trayOnSide ? trayHeight : math.min(trayHeight, slotSide + 18);

        final Size boardArea = trayOnSide
            ? Size(area.width - trayExtent - gap, area.height)
            : Size(boardSide, boardSide);

        final BoardGeometry geometry = BoardGeometry.fit(
          available: boardArea,
          rows: size,
          columns: size,
          gapFactor: BoardConfig.cellGapFactor,
          outerPadding: panelPadding * 2,
        );
        _geometry = geometry;

final Widget boardStack = AnimatedScale(
          scale: _squash ? 1 + MotionConfig.boardSquash : 1,
          duration: const Duration(milliseconds: MotionConfig.boardSquashTime),
          curve: Curves.easeOutBack,
          alignment: Alignment.center,
          child: SizedBox(
            key: _boardKey,
            height: trayOnSide ? null : boardArea.height,
            width: trayOnSide ? boardArea.width : boardArea.width,
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardSurfacePainter(
                      surfaceColor: palette.board,
                      outlineColor: palette.outline,
                      radius: AppRadius.lg,
                      shadowColor: Colors.black
                          .withOpacity(palette.isDark ? 0.40 : 0.24),
                      vignetteColor: Colors.black
                          .withOpacity(palette.isDark ? 0.30 : 0.22),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: BoardPainter(
                      board: _controller.board,
                      geometry: geometry,
                      palette: palette,
                      cellColor: palette.cell,
                      surfaceColor: palette.board,
                      ghost: _ghost,
                      aiming: widget.aiming,
                      repaint: _controller,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: EffectsPainter(
                        effects: widget.effects,
                        geometry: geometry,
                        blockStyle: palette.blockStyle,
                        repaint: widget.effects,
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: _DragLayer(
                      drag: _drag,
                      ghost: _ghost,
                      geometry: geometry,
                    ),
                  ),
                ),
                if (paused)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ColoredBox(
                        color: palette.background.withOpacity(0.55),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );

        final Widget tray = SizedBox(
          height: trayOnSide ? null : dockHeight,
          width: trayOnSide ? trayExtent : null,
          child: PieceTray(
            controller: _controller,
            slotKeys: _slotKeys,
            highlightedSlot: widget.highlightedSlot,
            dimmedSlot: _isDragging ? _pressedSlot : null,
            locked: _controller.inputLocked,
            vertical: trayOnSide,
          ),
        );

        return Listener(
          key: _rootKey,
          behavior: HitTestBehavior.opaque,
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: trayOnSide
              ? Row(
                  children: <Widget>[
                    Expanded(child: boardStack),
                    const SizedBox(width: gap),
                    tray,
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Center(child: boardStack),
                    const SizedBox(height: gap),
                    Center(child: tray),
                  ],
                ),
        );
      },
    );
  }
}

/// Value holder for the dragged piece. Kept out of the widget tree so only the
/// drag layer repaints while the pointer moves.
class _DragState {
  const _DragState({
    required this.slot,
    required this.pointer,
    required this.cellSize,
    required this.lifted,
  });

  final PieceSlot? slot;
  final Offset pointer;
  final double cellSize;
  final bool lifted;
}

/// Paints the piece that currently follows the pointer.
class _DragLayer extends StatelessWidget {
  const _DragLayer({
    required this.drag,
    required this.ghost,
    required this.geometry,
  });

  final ValueListenable<_DragState?> drag;
  final ValueListenable<GhostPreview?> ghost;
  final BoardGeometry geometry;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[drag, ghost]),
      builder: (BuildContext context, Widget? child) {
        final _DragState? value = drag.value;
        final GhostPreview? preview = ghost.value;
        if (value == null || value.slot == null || !value.lifted) {
          return const SizedBox.expand();
        }
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 170),
          curve: Curves.easeOutBack,
          builder: (BuildContext context, double lift, Widget? child) {
            return CustomPaint(
              painter: DragPiecePainter(
                slot: value.slot!,
                color: PiecePalette.byIndex(value.slot!.colorIndex),
                pointer: value.pointer,
                cellSize: value.cellSize,
                lift: lift,
                ghost: preview,
                geometry: geometry,
              ),
              child: const SizedBox.expand(),
            );
          },
        );
      },
    );
  }
}

/// Dragged piece renderer: lifts out of the tray, then snaps magnetically onto
/// the cells it is about to fill.
class DragPiecePainter extends CustomPainter {
  DragPiecePainter({
    required this.slot,
    required this.color,
    required this.pointer,
    required this.cellSize,
    this.lift = 1,
    this.ghost,
    this.geometry,
  });

  final PieceSlot slot;
  final PieceColor color;
  final Offset pointer;

  /// Cell size of the board, so the dragged piece aligns with the grid.
  final double cellSize;

  /// 0 right after pickup, 1 when fully lifted.
  final double lift;

  /// Preview under the piece, used for the magnetic snap and the rim tint.
  final GhostPreview? ghost;

  /// Board metrics, needed to snap onto real cells.
  final BoardGeometry? geometry;

  @override
  void paint(Canvas canvas, Size size) {
    final GridExtent extent = slot.extent;
    final GhostPreview? preview = ghost;
    final BoardGeometry? board = geometry;
    final bool valid = preview?.isValid ?? false;

    // Lift: the piece grows out of the finger instead of popping in at full
    // size. It ends a hair bigger than a board cell, which reads as "held".
    double cell = cellSize * (0.88 + 0.16 * lift);
    Offset origin =
        pointer - Offset(extent.width * cell / 2, extent.height * cell / 2);

    if (preview != null && valid && board != null) {
      // Magnetic snap: glide the piece towards the cells it will fill. The
      // anchor rect is inset by half a gap, so undo that to line the cells up
      // exactly with the board.
      final Rect anchor = board.cellRect(preview.topRow, preview.leftCol);
      final Offset target = anchor.topLeft - Offset(board.gap / 2, board.gap / 2);
      final double blend = (0.62 * lift).clamp(0.0, 1.0);
      origin = Offset.lerp(origin, target, blend)!;
      cell = cell + (board.cellSize - cell) * blend;
    }

    final double width = extent.width * cell;
    final double height = extent.height * cell;
    final Rect bounds = Rect.fromLTWH(origin.dx, origin.dy, width, height);

    // Contact shadow: two stacked ovals, cheap and soft enough at any size.
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, bounds.bottom + cell * 0.18),
        width: width * 0.86,
        height: height * 0.16,
      ),
      Paint()..color = Colors.black.withOpacity(0.14 + 0.16 * lift),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(bounds.center.dx, bounds.bottom + cell * 0.07),
        width: width * 0.62,
        height: height * 0.10,
      ),
      Paint()..color = Colors.black.withOpacity(0.18 + 0.16 * lift),
    );

    final BoardGeometry dragGeometry = BoardGeometry(
      origin: origin,
      cellSize: cell,
      gap: cell * BoardConfig.cellGapFactor,
      rows: extent.height,
      columns: extent.width,
    );

    final double alpha = (0.6 + 0.4 * lift).clamp(0.0, 1.0);
    for (final GridPosition position in slot.cells) {
      BlockPainter.paint(
        canvas,
        dragGeometry.cellRect(position.row, position.col),
        color,
        alpha: alpha,
      );
    }

    if (preview != null) {
      final Color rimColor = valid ? Colors.white : AppColors.danger;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          bounds.inflate(cell * 0.08),
          Radius.circular(cell * 0.30),
        ),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1.6, cell * 0.05)
          ..color = rimColor.withOpacity(
            (valid ? 0.28 : 0.6) * lift.clamp(0.0, 1.0),
          ),
      );
    }
  }

  @override
  bool shouldRepaint(DragPiecePainter oldDelegate) =>
      oldDelegate.slot != slot ||
      oldDelegate.pointer != pointer ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.lift != lift ||
      oldDelegate.ghost != ghost ||
      oldDelegate.geometry != geometry ||
      oldDelegate.color != color;
}