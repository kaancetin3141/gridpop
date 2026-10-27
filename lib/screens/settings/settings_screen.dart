import 'package:flutter/material.dart';

import '../../audio/audio_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/responsive.dart';
import '../../state/app_scope.dart';
import '../../widgets/app_background.dart';
import '../../widgets/animations/motion.dart';
import '../../widgets/buttons/game_buttons.dart';
import '../../widgets/dialogs/app_dialogs.dart';

/// Settings screen: gameplay, audio, appearance and data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.showBackButton = true});

  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final services = AppScope.of(context);
    final settings = services.settings;

    return AppScaffold(
      child: ListenableBuilder(
        listenable: settings,
        builder: (BuildContext context, Widget? child) {
          return Column(
            children: <Widget>[
              Padding(
                padding: Responsive.pagePadding(context),
                child: Row(
                  children: <Widget>[
                    if (showBackButton) ...<Widget>[
                      IconPillButton(
                        icon: Icons.arrow_back_rounded,
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    Expanded(
                      child: Text(
                        strings.t('settings.title'),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    4,
                    20,
                    32 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _SectionHeader(label: strings.t('settings.game')),
                          _Group(
                            children: <Widget>[
                              _SegmentedRow<int>(
                                label: strings.t('settings.boardSize'),
                                values: BoardConfig.selectableSizes,
                                selected: settings.boardSize,
                                labelBuilder: (int value) => '${value}x$value',
                                onChanged: settings.setBoardSize,
                              ),
                              _SwitchTile(
                                label: strings.t('settings.showGhost'),
                                value: settings.showGhost,
                                onChanged: settings.setShowGhost,
                              ),
                              _SwitchTile(
                                label: strings.t('settings.showHints'),
                                value: settings.showHints,
                                onChanged: settings.setShowHints,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _SectionHeader(label: strings.t('settings.audio')),
                          _Group(
                            children: <Widget>[
                              _SwitchTile(
                                label: strings.t('settings.sound'),
                                icon: Icons.graphic_eq_rounded,
                                value: settings.soundEnabled,
                                onChanged: (bool value) {
                                  settings.setSoundEnabled(value);
                                  if (value) {
                                    services.audio.play(GameSound.buttonClick);
                                  }
                                },
                              ),
                              _SwitchTile(
                                label: strings.t('settings.music'),
                                icon: Icons.music_note_rounded,
                                value: settings.musicEnabled,
                                onChanged: settings.setMusicEnabled,
                              ),
                              _SwitchTile(
                                label: strings.t('settings.vibration'),
                                icon: Icons.vibration_rounded,
                                value: settings.vibrationEnabled,
                                onChanged: settings.setVibrationEnabled,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _SectionHeader(label: strings.t('settings.appearance')),
                          _Group(
                            children: <Widget>[
                              _ThemeSelector(
                                value: settings.themeMode,
                                onChanged: settings.setThemeMode,
                              ),
                              _LanguageSelector(
                                value: settings.languageCode,
                                onChanged: settings.setLanguageCode,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          _SectionHeader(label: strings.t('settings.data')),
                          _Group(
                            children: <Widget>[
                              _ActionTile(
                                label: strings.t('settings.resetProgress'),
                                icon: Icons.restart_alt_rounded,
                                tone: AppColors.danger,
                                onTap: () => _resetProgress(context, services),
                              ),
                              const _AboutTile(version: '1.0.0'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _resetProgress(
    BuildContext context,
    AppServices services,
  ) async {
    final AppStrings strings = AppStrings.of(context);
    final bool confirmed = await showConfirmDialog(
      context,
      title: strings.t('settings.resetProgress'),
      message: strings.t('settings.resetMessage'),
      confirmLabel: strings.t('common.clear'),
      destructive: true,
    );
    if (!confirmed || !context.mounted) {
      return;
    }
    await services.stats.reset();
    await services.leaderboard.clear();
    await services.wallet.reset();
    await services.inventory.reset();
    await services.achievements.reset();
    await services.daily.reset();
    if (context.mounted) {
      showToast(context, strings.t('settings.resetDone'));
    }
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: AppSpacing.sm),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: palette.textMuted,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
        boxShadow: AppShadows.soft(
          palette.isDark ? Colors.black : AppColors.indigo,
          strength: 0.6,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: <Widget>[
            for (int i = 0; i < children.length; i++) ...<Widget>[
              if (i > 0)
                Divider(height: 1, color: palette.outline.withOpacity(0.6)),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
    this.icon,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 4,
      ),
      title: Text(label, style: Theme.of(context).textTheme.titleMedium),
      subtitle: icon == null
          ? null
          : Icon(icon, size: 18, color: palette.textMuted),
      secondary: null,
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.tone,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final Color color = tone ?? AppColors.indigo;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: 2,
      ),
      leading: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(color: color),
      ),
    );
  }
}

class _AboutTile extends StatelessWidget {
  const _AboutTile({required this.version});

  final String version;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.info_outline_rounded, size: 18, color: palette.textMuted),
              const SizedBox(width: 8),
              Text(
                '${strings.t('settings.version')} $version',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: palette.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            strings.t('settings.original'),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: palette.textMuted),
          ),
        ],
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.value, required this.onChanged});

  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.t('settings.theme'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final ThemeMode mode in ThemeMode.values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChoiceChip(
                      label: switch (mode) {
                        ThemeMode.system => strings.t('settings.themeSystem'),
                        ThemeMode.light => strings.t('settings.themeLight'),
                        ThemeMode.dark => strings.t('settings.themeDark'),
                      },
                      icon: switch (mode) {
                        ThemeMode.system => Icons.brightness_auto_rounded,
                        ThemeMode.light => Icons.light_mode_rounded,
                        ThemeMode.dark => Icons.dark_mode_rounded,
                      },
                      selected: mode == value,
                      onTap: () => onChanged(mode),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageSelector extends StatelessWidget {
  const _LanguageSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.t('settings.language'), style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final String code in AppStrings.supportedLanguageCodes)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _ChoiceChip(
                      label: AppStrings.languageName(code),
                      icon: Icons.translate_rounded,
                      selected: code == value,
                      onTap: () => onChanged(code),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.indigo.withOpacity(0.12) : palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: selected ? AppColors.indigo : palette.outline,
          ),
        ),
        child: Column(
          children: <Widget>[
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.indigo : palette.textMuted,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.indigo : palette.textMuted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentedRow<T> extends StatelessWidget {
  const _SegmentedRow({
    required this.label,
    required this.values,
    required this.selected,
    required this.labelBuilder,
    required this.onChanged,
  });

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T value) labelBuilder;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              for (final T value in values)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Pressable(
                      onTap: () => onChanged(value),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: value == selected
                              ? AppColors.indigo
                              : palette.surfaceAlt,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Text(
                          labelBuilder(value),
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(
                                color: value == selected
                                    ? Colors.white
                                    : palette.textMuted,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}