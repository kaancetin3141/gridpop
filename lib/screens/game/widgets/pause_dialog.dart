import 'package:flutter/material.dart';

import '../../../core/constants/app_strings.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../widgets/buttons/game_buttons.dart';

/// Options offered by the pause overlay.
enum PauseAction { resume, restart, quit }

/// Pause overlay. Returns the action chosen by the player.
Future<PauseAction?> showPauseDialog(BuildContext context) {
  return showDialog<PauseAction>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.5),
    builder: (BuildContext context) => const _PauseDialog(),
  );
}

class _PauseDialog extends StatelessWidget {
  const _PauseDialog();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);
    final TextTheme text = Theme.of(context).textTheme;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: AppColors.auroraGradient,
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pause_rounded,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                strings.t('game.paused').toUpperCase(),
                style: text.headlineSmall?.copyWith(letterSpacing: 1.6),
              ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: strings.t('common.resume'),
                icon: Icons.play_arrow_rounded,
                onPressed: () => Navigator.of(context).pop(PauseAction.resume),
              ),
              const SizedBox(height: AppSpacing.md),
              SoftButton(
                label: strings.t('common.restart'),
                icon: Icons.refresh_rounded,
                onPressed: () => Navigator.of(context).pop(PauseAction.restart),
              ),
              const SizedBox(height: AppSpacing.md),
              SoftButton(
                label: strings.t('common.quit'),
                icon: Icons.exit_to_app_rounded,
                tone: AppColors.danger,
                onPressed: () => Navigator.of(context).pop(PauseAction.quit),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.t('app.name'),
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: palette.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}