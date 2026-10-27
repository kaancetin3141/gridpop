import 'dart:async';

import 'package:flutter/material.dart';

import '../core/constants/app_strings.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

/// Rewarded ads, currently a clearly labelled simulation.
///
/// The flow is production shaped (countdown -> claim -> reward) so a real ad
/// SDK can replace [_SimulatedAdDialog] later without touching the callers.
class AdRewardService {
  const AdRewardService();

  /// Shows one rewarded ad. Completes with `true` when the viewer watched long
  /// enough to earn the reward.
  Future<bool> showRewardedAd(
    BuildContext context, {
    int rewardCoins = CoinConfig.adReward,
  }) async {
    final bool? watched = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => _SimulatedAdDialog(
        rewardCoins: rewardCoins,
      ),
    );
    return watched ?? false;
  }
}

/// Five second placeholder standing in for a real rewarded video.
class _SimulatedAdDialog extends StatefulWidget {
  const _SimulatedAdDialog({required this.rewardCoins});

  final int rewardCoins;

  @override
  State<_SimulatedAdDialog> createState() => _SimulatedAdDialogState();
}

class _SimulatedAdDialogState extends State<_SimulatedAdDialog> {
  static const int _waitSeconds = 5;

  late int _remaining = _waitSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        return;
      }
      if (_remaining <= 1) {
        timer.cancel();
        setState(() => _remaining = 0);
        return;
      }
      setState(() => _remaining--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = AppStrings.of(context);
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
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.mint.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_circle_fill_rounded,
                  color: AppColors.mint,
                  size: 30,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                strings.t('shop.adTitle'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.t('shop.adBody'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                strings.t('shop.adNote'),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: palette.textMuted),
              ),
              const SizedBox(height: AppSpacing.xl),
              _remaining > 0
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              palette.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${strings.t('shop.adWaiting')}: ${_remaining}s',
                          style: Theme.of(context)
                              .textTheme
                              .labelMedium
                              ?.copyWith(color: palette.textMuted),
                        ),
                      ],
                    )
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mint,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(
                          '${strings.t('shop.adClaim')} (+${widget.rewardCoins})',
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
