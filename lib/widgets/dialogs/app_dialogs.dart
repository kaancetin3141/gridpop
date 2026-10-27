import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../buttons/game_buttons.dart';

/// Themed confirmation dialog. Returns `true` when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
  String? cancelLabel,
  bool destructive = false,
}) async {
  final AppStrings strings = AppStrings.of(context);
  final bool? result = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (BuildContext context) {
      return _ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel ?? strings.t('common.confirm'),
        cancelLabel: cancelLabel ?? strings.t('common.cancel'),
        destructive: destructive,
      );
    },
  );
  return result ?? false;
}

class _ConfirmDialog extends StatelessWidget {
  const _ConfirmDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: (destructive ? AppColors.danger : AppColors.indigo)
                      .withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  destructive ? Icons.warning_amber_rounded : Icons.help_outline_rounded,
                  color: destructive ? AppColors.danger : AppColors.indigo,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: <Widget>[
                  Expanded(
                    child: SoftButton(
                      label: cancelLabel,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      label: confirmLabel,
                      height: 52,
                      colors: destructive
                          ? const <Color>[AppColors.danger, Color(0xFFFF9A6B)]
                          : null,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rounded snackbar used for short confirmations ("Progress cleared").
void showToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message, textAlign: TextAlign.center),
        duration: const Duration(milliseconds: 1600),
        width: 320,
      ),
    );
}

/// Golden toast celebrating a freshly unlocked achievement. Toasts queue in
/// the messenger, so several unlocks in a row each get their moment.
void showAchievementToast(BuildContext context, {required String title}) {
  final AppStrings strings = AppStrings.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: <Color>[AppColors.gold, AppColors.amber],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  strings.t('achievements.toast'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 2000),
      width: 340,
    ),
  );
}