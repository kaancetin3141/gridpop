import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

import '../../core/utils/responsive.dart';
import '../../game/achievements/achievement.dart';
import '../../game/achievements/achievement_engine.dart';
import '../../game/models/game_event.dart';
import '../../game/models/game_mode.dart';
import '../../game/models/game_state.dart';
import '../../game/models/game_phase.dart';
import '../../game/models/grid_position.dart';
import '../../game/models/piece_slot.dart';
import '../../game/models/placement_outcome.dart';
import '../../game/services/game_controller.dart';
import '../../game/widgets/effects/effects_layer.dart';
import '../../game/widgets/game_board_view.dart';
import '../../game/widgets/game_hud.dart';
import '../../shop/shop_item.dart';
import '../../state/app_scope.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../../widgets/dialogs/app_dialogs.dart';
import 'widgets/game_over_dialog.dart';
import 'widgets/pause_dialog.dart';
import 'widgets/power_bar.dart';
import 'widgets/revive_dialog.dart';

/// The play screen: HUD, board, tray and every in-game overlay.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.mode,
    this.controller,
  });

  final GameMode mode;

  /// Optional pre-built controller. When `null` the screen builds and owns one
  /// from the services in [AppScope]; tests inject their own instance.
  final GameController? controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  final GlobalKey<GameBoardViewState> _boardKey =
      GlobalKey<GameBoardViewState>();

  GameController? _controllerOrNull;
  GameEffects? _effectsOrNull;
  late final AnimationController _shake;

  /// Small impact shake fired when lines pop.
  late final AnimationController _clearShake;

  /// Amplitude driver for [_clearShake] (grows with the number of lines).
  double _clearShakeEnergy = 1;

  /// True when the controller was injected and must not be disposed here.
  bool _ownsController = false;

  int? _hintSlot;
  bool _gameOverShown = false;

  /// Power-up waiting for a target cell (hammer/bomb).
  ShopItemId? _aimItem;

  /// Guards against stacking two revive sheets.
  bool _reviveDialogOpen = false;

  /// Platform "reduce motion" support: shake, squash and heavy flashes are off.
  bool get _reducedMotion => MediaQuery.disableAnimationsOf(context);

  String get noMoveFatalText => AppStrings.of(context).t('game.noMoves');

  String get noMoveSoftText => AppStrings.of(context).t('game.noMovesSoft');

  GameEffects get _effects => _effectsOrNull!;

  GameController get _controller => _controllerOrNull!;

  @override
  void initState() {
    super.initState();
    _shake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: MotionConfig.boardShakeInvalid),
    )..addListener(_repaintBoard);
    _clearShake = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 210),
    )..addListener(_repaintBoard);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controllerOrNull != null) {
      return;
    }
    // Services come from the widget tree, so they are resolved here instead of
    // in initState.
    final services = AppScope.of(context);
    _effectsOrNull ??= GameEffects();

    final GameController? injected = widget.controller;
    if (injected != null) {
      _controllerOrNull = injected;
      _ownsController = false;
    } else {
      _controllerOrNull = GameController(
        stats: services.stats,
        leaderboard: services.leaderboard,
        daily: services.daily,
        audio: services.audio,
        haptics: services.haptics,
        wallet: services.wallet,
        preferredBoardSize: services.settings.boardSize,
      );
      _ownsController = true;
    }
    _controllerOrNull!.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) => _startRun());
  }

  Future<void> _startRun() async {
    _effects.reset();
    _gameOverShown = false;
    _hintSlot = null;
    _aimItem = null;
    if (mounted) {
      setState(() {});
    }
    await _controller.start(mode: widget.mode);
  }

  @override
  void dispose() {
    _controllerOrNull?.removeListener(_onControllerChanged);
    // Stop the run timers even when the controller was injected: nothing
    // should keep ticking once the play screen is gone.
    _controllerOrNull?.stopTimers();
    if (_ownsController) {
      _controllerOrNull?.dispose();
    }
    _effectsOrNull?.dispose();
    _shake.dispose();
    _clearShake.dispose();
    super.dispose();
  }

  void _repaintBoard() {
    if (mounted) {
      setState(() {});
    }
  }

  // --- controller events --------------------------------------------------

  void _onControllerChanged() {
    final List<GameEvent> events = _controller.drainEvents();
    for (final GameEvent event in events) {
      _handleEvent(event);
    }
    if (mounted) {
      setState(() {});
    }
  }

  void _handleEvent(GameEvent event) {
    switch (event.type) {
      case GameEventType.placed:
        final PlacementOutcome outcome = event.payload as PlacementOutcome;
        _effects.onPlaced(outcome);
        _effects.onCleared(outcome, boardSize: _controller.board.size);
        // Small impact shake: the screen trembles when lines pop.
        if (outcome.hasClear && !_reducedMotion) {
          _clearShakeEnergy = 1 + outcome.lineCount * 0.9;
          _clearShake.forward(from: 0);
        }
        // Close the input gate: no new piece appears until the placement and
        // the line clear are done.
        _controller.lockInput();
        _boardKey.currentState?.ensureAnimating();
        _hintSlot = null;
        unawaited(_celebrateAchievements(_runSnapshot()));
      case GameEventType.settled:
        // Nothing to do here: the board view already called completePlacement.
        break;
      case GameEventType.noMove:
        _effects.onNoMove(
          fatal: _controller.mode.config.allowsGameOver,
        );
        _boardKey.currentState?.ensureAnimating();
        if (!_controller.mode.config.allowsGameOver) {
          _notifyPlayer(noMoveSoftText);
        } else {
          _notifyPlayer(noMoveFatalText);
        }
      case GameEventType.invalid:
        if (!_reducedMotion) {
          _shake.forward(from: 0);
        }
        _hapticWarning();
      case GameEventType.newRecord:
        _effects.onNewRecord();
        _boardKey.currentState?.ensureAnimating();
      case GameEventType.booster:
        final int seconds = event.payload is int
            ? event.payload! as int
            : BoosterConfig.manualDurationSeconds;
        _effects.onBooster(seconds);
        _boardKey.currentState?.ensureAnimating();
      case GameEventType.boardCleared:
        final List<TintedCell> cells = event.payload is List<TintedCell>
            ? event.payload! as List<TintedCell>
            : const <TintedCell>[];
        _effects.onBoardCleared(cells);
        if (!_reducedMotion) {
          _clearShakeEnergy = 3.2;
          _clearShake.forward(from: 0);
        }
        _boardKey.currentState?.ensureAnimating();
      case GameEventType.blocksSmashed:
        final List<TintedCell> smashedCells = event.payload is List<TintedCell>
            ? event.payload! as List<TintedCell>
            : const <TintedCell>[];
        _effects.onBoardCleared(smashedCells);
        _boardKey.currentState?.ensureAnimating();
      case GameEventType.reviveOffered:
        _aimItem = null;
        if (!_reviveDialogOpen) {
          // Let the no-move feedback land before the sheet covers the board.
          Future<void>.delayed(
            const Duration(milliseconds: 260),
            _offerRevive,
          );
        }
      case GameEventType.reviveStarted:
        final List<TintedCell> revivedCells = event.payload is List<TintedCell>
            ? event.payload! as List<TintedCell>
            : const <TintedCell>[];
        _effects.reset();
        _effects.onBoardCleared(revivedCells);
        if (!_reducedMotion) {
          _clearShakeEnergy = 4.0;
          _clearShake.forward(from: 0);
        }
        _boardKey.currentState?.ensureAnimating();
        _gameOverShown = false;
        _hintSlot = null;
        if (mounted) {
          setState(() => _aimItem = null);
        }
      case GameEventType.coinsEarned:
        final int amount = event.payload is int ? event.payload! as int : 0;
        if (amount > 0) {
          _notifyPlayer(
            '+$amount ${AppStrings.of(context).t('shop.coinsName')}',
          );
        }
      case GameEventType.gameOver:
        unawaited(_celebrateAchievements(
            _runSnapshot(summary: event.payload as GameEndSummary)));
        _showGameOver(event.payload as GameEndSummary);
      case GameEventType.started:
      case GameEventType.rotated:
      case GameEventType.consumed:
      case GameEventType.trayRefilled:
      case GameEventType.trayReset:
      case GameEventType.warning:
      case GameEventType.boosterEnded:
        break;
    }
  }

  /// "Nothing fits" feedback: toast plus haptic, so the player is never left
  /// guessing why the piece cannot be dropped.
  void _notifyPlayer(String message) {
    _hapticWarning();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          duration: const Duration(milliseconds: 1400),
          width: 340,
        ),
      );
  }

  void _hapticWarning() {
    _controller.playWarningCue();
  }

  Future<void> _showGameOver(GameEndSummary summary) async {
    if (_gameOverShown) {
      return;
    }
    _gameOverShown = true;
    // The run is over: dim the board immediately so the player never sits in
    // a finished run that looks alive.
    if (mounted) {
      setState(() {});
    }
    // Let the clear animation breathe before the dialog pops in.
    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) {
      return;
    }

    await showGameOverDialog(
      context,
      summary: summary,
      onRetry: () async {
        _effects.reset();
        _gameOverShown = false;
        if (mounted) {
          setState(() => _hintSlot = null);
        }
        await _controller.restart();
      },
      onMenu: () => _quit(confirmed: true),
    );
  }

  Future<void> _pause() async {
    if (!_controller.state.acceptsInput) {
      return;
    }
    _controller.pause();
    AppScope.of(context).audio.play(GameSound.buttonClick);

    final PauseAction? action = await showPauseDialog(
      context,
      score: _controller.score,
      seconds: _controller.elapsedSeconds,
      combo: _controller.bestCombo,
    );
    if (!mounted) {
      return;
    }
    switch (action) {
      case PauseAction.resume:
        _controller.resume();
      case PauseAction.restart:
        _effects.reset();
        await _controller.restart();
      case PauseAction.quit:
      case null:
        await _quit(confirmed: true);
    }
  }

  Future<void> _quit({bool confirmed = false}) async {
    if (!confirmed) {
      final AppStrings strings = AppStrings.of(context);
      final bool leave = await showConfirmDialog(
        context,
        title: strings.t('game.quitConfirm'),
        message: strings.t('game.quitMessage'),
        confirmLabel: strings.t('common.quit'),
        cancelLabel: strings.t('common.continue'),
        destructive: true,
      );
      if (!leave || !mounted) {
        return;
      }
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Spends a stocked power-up from the shop.
  Future<void> _usePowerUp(ShopItemId item) async {
    final services = AppScope.of(context);
    if (!_controller.state.acceptsInput) {
      return;
    }
    if (services.inventory.countOf(item) <= 0) {
      _notifyPlayer(AppStrings.of(context).t('power.none'));
      return;
    }

    // Hammer and bomb need a target: arm the tool and let the board decide.
    if (item == ShopItemId.hammer || item == ShopItemId.bomb) {
      setState(() => _aimItem = _aimItem == item ? null : item);
      services.audio.play(GameSound.buttonClick);
      return;
    }

    bool applied = false;
    switch (item) {
      case ShopItemId.refreshTray:
        applied = _controller.refreshTray();
      case ShopItemId.clearBoard:
        applied = _controller.clearBoard();
      case ShopItemId.booster:
        applied = _controller.activateBooster();
      case ShopItemId.hammer:
      case ShopItemId.bomb:
        break;
    }
    if (applied) {
      await services.inventory.consume(item);
      services.audio.play(GameSound.buttonClick);
    }
  }

  /// Applies the armed hammer/bomb to [cell].
  Future<void> _onCellTap(GridPosition cell) async {
    final ShopItemId? item = _aimItem;
    if (item == null) {
      return;
    }
    final AppServices services = AppScope.of(context);
    final bool applied = switch (item) {
      ShopItemId.hammer => _controller.hammerAt(cell.row, cell.col),
      ShopItemId.bomb => _controller.bombAt(cell.row, cell.col),
      _ => false,
    };
    if (!applied) {
      _notifyPlayer(AppStrings.of(context).t('power.noTarget'));
      if (mounted) {
        setState(() => _aimItem = null);
      }
      return;
    }
    await services.inventory.consume(item);
    if (mounted) {
      setState(() => _aimItem = null);
    }
  }

  /// Asks the player whether they want their one second chance of the run.
  Future<void> _offerRevive() async {
    if (!mounted || _reviveDialogOpen) {
      return;
    }
    _reviveDialogOpen = true;
    final AppServices services = AppScope.of(context);
    final int cost = _controller.reviveCost;
    final ReviveChoice? choice = await showReviveDialog(
      context,
      cost: cost,
      canAfford: services.wallet.coins >= cost,
      adAvailable: true,
    );
    _reviveDialogOpen = false;
    if (!mounted) {
      return;
    }

    switch (choice) {
      case ReviveChoice.coins:
        final bool revived = await _controller.revive();
        if (!revived) {
          await _controller.declineRevive();
        }
      case ReviveChoice.ad:
        final bool watched = await services.ads.showRewardedAd(context);
        if (!mounted) {
          return;
        }
        if (watched) {
          final bool revived = await _controller.revive(free: true);
          if (!revived) {
            await _controller.declineRevive();
          }
        } else {
          await _controller.declineRevive();
        }
      case ReviveChoice.giveUp:
      case null:
        await _controller.declineRevive();
    }
  }

  /// Snapshot of the lifetime statistics plus the current run, used to judge
  /// the achievement badges.
  AchievementSnapshot _runSnapshot({GameEndSummary? summary}) {
    final AppServices services = AppScope.of(context);
    final GameState state = _controller.state;
    return AchievementSnapshot(
      gamesPlayed: services.stats.gamesPlayed,
      totalLinesCleared: services.stats.totalLinesCleared,
      totalCellsPlaced: services.stats.totalCellsPlaced,
      perfectMoves: services.stats.perfectMoves,
      bestCombo: services.stats.bestCombo,
      highScore: services.stats.highScore,
      totalPlaySeconds: services.stats.totalPlaySeconds,
      runScore: state.score,
      runCombo: state.bestComboThisRun,
      runPerfectMoves: state.perfectMoves,
      runMode: state.mode,
      runDailyCompleted: summary != null && state.mode == GameMode.daily,
      runDailyStars: summary?.stars ?? 0,
    );
  }

  /// Unlocks and announces freshly earned badges.
  Future<void> _celebrateAchievements(AchievementSnapshot snapshot) async {
    final AppServices services = AppScope.of(context);
    final List<Achievement> fresh =
        await services.achievements.evaluate(snapshot);
    if (!mounted || fresh.isEmpty) {
      return;
    }
    services.audio.play(GameSound.highScore);
    final AppStrings strings = AppStrings.of(context);
    for (final Achievement achievement in fresh) {
      if (!mounted) {
        return;
      }
      showAchievementToast(context, title: strings.t(achievement.titleKey));
    }
  }

  void _showHint() {
    final PlacementHint? move = _controller.hint();
    if (move == null) {
      // No suggestion means the tray may be dead: resolve the run instead of
      // silently doing nothing.
      _controller.checkForDeadTray();
      return;
    }
    final PieceSlot? slot = _controller.slotAt(move.slotIndex);
    if (slot == null) {
      return;
    }
    // Rotate the tray piece first so the highlighted cells match what the
    // player is holding.
    for (int i = 0; i < move.rotation; i++) {
      _controller.rotateSlot(move.slotIndex);
    }
    final List<GridPosition> oriented =
        _controller.slotAt(move.slotIndex)?.cells ?? const <GridPosition>[];

    _effects.onHint(
      <GridPosition>[
        for (final GridPosition cell in oriented)
          GridPosition(cell.row + move.topRow, cell.col + move.leftCol),
      ],
      slot.colorIndex,
    );
    _boardKey.currentState?.ensureAnimating();
    AppScope.of(context).audio.play(GameSound.buttonClick);
    setState(() => _hintSlot = move.slotIndex);
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted && _hintSlot == move.slotIndex) {
        setState(() => _hintSlot = null);
      }
    });
  }

  // --- build --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final Size screen = MediaQuery.sizeOf(context);
    final bool shortScreen = screen.height < Breakpoints.shortHeight;

    final Widget board = AnimatedBuilder(
      animation: Listenable.merge(<Listenable>[_shake, _clearShake]),
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeOut.transform(_shake.value);
        final double invalid =
            math.sin(_shake.value * math.pi * 4) * 7 * (1 - t);
        final double clearT = Curves.easeOut.transform(_clearShake.value);
        final double clear = math.sin(_clearShake.value * math.pi * 6) *
            _clearShakeEnergy *
            (1 - clearT);
        // A little vertical kick makes the impact feel physical.
        final double clearY = math.sin(_clearShake.value * math.pi * 6 + 1.1) *
            _clearShakeEnergy *
            0.45 *
            (1 - clearT);
        return Transform.translate(
          offset: Offset(invalid + clear, clearY),
          child: child,
        );
      },
      // The board slides up and fades in once per run. Scale stays at 1 so the
      // drag math (which works in global coordinates) is never distorted.
      child: PopIn(
        offset: const Offset(0, 0.035),
        scale: 1,
        child: GameBoardView(
          key: _boardKey,
          controller: _controller,
          effects: _effects,
          showGhost: AppScope.of(context).settings.showGhost,
          highlightedSlot: _hintSlot,
          aiming: _aimItem != null,
          onCellTap: _onCellTap,
          onSettled: _controller.completePlacement,
        ),
      ),
    );

    // On short screens the hint button joins the top bar so the board keeps
    // as much height as possible.
    final Widget? hintButton = AppScope.of(context).settings.showHints
        ? IconPillButton(
            icon: Icons.lightbulb_rounded,
            tooltip: AppStrings.of(context).t('game.hint'),
            tone: AppColors.amber,
            size: shortScreen ? 38 : 46,
            onPressed: _showHint,
          )
        : null;

    return AppScaffold(
      blooms: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Responsive.pagePadding(context).left,
          shortScreen ? 4 : 8,
          Responsive.pagePadding(context).right,
          4 + MediaQuery.paddingOf(context).bottom * 0.5,
        ),
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: GameTopBar(
                    controller: _controller,
                    compact: shortScreen,
                    onQuit: _quit,
                    onPause: _controller.phase == GamePhase.paused
                        ? _controller.resume
                        : _pause,
                    trailing: hintButton,
                  ),
                ),
              ],
            ),
            SizedBox(height: shortScreen ? 2 : 6),
            GameHudRow(controller: _controller, compact: shortScreen),
            SizedBox(height: shortScreen ? 2 : 8),
            Expanded(child: board),
            const SizedBox(height: 8),
            if (_aimItem != null) ...<Widget>[
              _AimBanner(
                label: AppStrings.of(context).t(
                  _aimItem == ShopItemId.bomb
                      ? 'power.aimBomb'
                      : 'power.aimHammer',
                ),
                onCancel: () => setState(() => _aimItem = null),
              ),
              const SizedBox(height: 6),
            ],
            PowerBar(compact: shortScreen, onUse: _usePowerUp),
            if (!shortScreen) ...<Widget>[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: hintButton ?? const SizedBox.shrink(),
              ),
            ],
            SizedBox(height: palette.isDark ? 6 : 2),
          ],
        ),
      ),
    );
  }
}

/// Slim instruction strip shown while the hammer/bomb waits for a target.
class _AimBanner extends StatelessWidget {
  const _AimBanner({required this.label, required this.onCancel});

  final String label;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.grape.withOpacity(0.55)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.touch_app_rounded, size: 16, color: AppColors.grape),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onCancel,
            child: Text(
              strings.t('power.aimCancel'),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.coral,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
