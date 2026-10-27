import 'package:flutter/material.dart';

import '../../core/constants/app_strings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/piece_palette.dart';
import '../../core/utils/responsive.dart';
import '../../game/models/piece_shape.dart';
import '../../game/models/piece_slot.dart';
import '../../game/widgets/painting/piece_preview_painter.dart';
import '../../widgets/app_background.dart';
import '../../widgets/buttons/game_buttons.dart';

/// Tutorial page: rules, scoring table and the full shape gallery.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
    final AppPalette palette = AppPalette.of(context);

    final List<_Rule> rules = <_Rule>[
      _Rule(Icons.pan_tool_alt_rounded, strings.t('how.drag'), AppColors.indigo),
      _Rule(Icons.grid_4x4_rounded, strings.t('how.snap'), AppColors.sky),
      _Rule(Icons.auto_delete_rounded, strings.t('how.clear'), AppColors.mint),
      _Rule(Icons.filter_9_plus_rounded, strings.t('how.multi'), AppColors.amber),
      _Rule(Icons.local_fire_department_rounded, strings.t('how.combo'), AppColors.coral),
      _Rule(Icons.rotate_right_rounded, strings.t('how.rotate'), AppColors.magenta),
      _Rule(Icons.gavel_rounded, strings.t('how.tools'), AppColors.mint),
      _Rule(Icons.favorite_rounded, strings.t('how.revive'), AppColors.bubblegum),
      _Rule(Icons.block_rounded, strings.t('how.over'), AppColors.violet),
      _Rule(Icons.self_improvement_rounded, strings.t('how.zen'), AppColors.grape),
    ];

    return AppScaffold(
      child: Column(
        children: <Widget>[
          Padding(
            padding: Responsive.pagePadding(context),
            child: Row(
              children: <Widget>[
                IconPillButton(
                  icon: Icons.arrow_back_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    strings.t('how.title'),
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
                28 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _Card(
                        children: <Widget>[
                          for (int i = 0; i < rules.length; i++)
                            Padding(
                              padding: EdgeInsets.only(
                                top: i == 0 ? 0 : AppSpacing.md,
                              ),
                              child: _RuleTile(rule: rules[i]),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        strings.t('how.scoring').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _ScoringTable(),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        strings.t('how.shapes').toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: palette.textMuted,
                              letterSpacing: 1.2,
                            ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      const _ShapeGallery(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Rule {
  const _Rule(this.icon, this.text, this.color);

  final IconData icon;
  final String text;
  final Color color;
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({required this.rule});

  final _Rule rule;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: rule.color.withOpacity(0.14),
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(rule.icon, size: 18, color: rule.color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            rule.text,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: palette.text),
          ),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _ScoringTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<List<String>> rows = <List<String>>[
      <String>['score.cells', '+1'],
      <String>['score.lines', '+10'],
      <String>['score.multi', '+15'],
      <String>['score.perfect', '+60'],
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
      ),
      child: Column(
        children: <Widget>[
          for (final List<String> row in rows)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: <Widget>[
                  Text(
                    AppStrings.of(context).t(row[0]),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  Text(
                    row[1],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.amber,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Grid of every shape in the catalogue, rendered with the in-game material.
class _ShapeGallery extends StatelessWidget {
  const _ShapeGallery();

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final List<PieceShape> shapes = PieceShapeLibrary.build().all;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: palette.outline),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final int columns = constraints.maxWidth > 420 ? 4 : 3;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (int i = 0; i < shapes.length; i++)
                SizedBox(
                  width: (constraints.maxWidth - (columns - 1) * 8) / columns,
                  child: _ShapeTile(
                    slot: PieceSlot(
                      index: i,
                      shape: shapes[i],
                      colorIndex: i % PiecePalette.all.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ShapeTile extends StatelessWidget {
  const _ShapeTile({required this.slot});

  final PieceSlot slot;

  @override
  Widget build(BuildContext context) {
    final AppPalette palette = AppPalette.of(context);
    final AppStrings strings = AppStrings.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 44,
            child: CustomPaint(
              painter: PiecePreviewPainter(slot: slot, maxCell: 30),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            strings.t(slot.shape.labelKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: palette.textMuted, fontSize: 9.5),
          ),
        ],
      ),
    );
  }
}