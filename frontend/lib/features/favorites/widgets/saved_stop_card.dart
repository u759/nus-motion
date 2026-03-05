import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/state/providers.dart';

class SavedStopCard extends ConsumerWidget {
  final String stopName;
  final VoidCallback onDismissed;

  const SavedStopCard({
    super.key,
    required this.stopName,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttlesAsync = ref.watch(shuttlesProvider(stopName));

    return Dismissible(
      key: ValueKey(stopName),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppTheme.spacing24),
        decoration: BoxDecoration(
          color: AppTheme.error.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(Icons.delete, color: AppTheme.error),
      ),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.spacing20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: shuttlesAsync.when(
          data: (result) => _buildContent(context, result.shuttles),
          loading: () => _buildShimmer(),
          error: (_, _) => _buildContent(context, []),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.neutralDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing16),
          Container(
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, List<Shuttle> shuttles) {
    final theme = Theme.of(context);
    Shuttle? soonest;
    int? soonestMinutes;
    for (final s in shuttles) {
      if (s.arrivalTime == 'Arr') {
        soonest = s;
        soonestMinutes = 0;
        break;
      }
      final mins = int.tryParse(s.arrivalTime);
      if (mins != null && (soonestMinutes == null || mins < soonestMinutes)) {
        soonest = s;
        soonestMinutes = mins;
      }
    }

    final arrivalText = soonest != null
        ? (soonest.arrivalTime == 'Arr'
              ? 'Arriving Now'
              : formatEta(soonest.arrivalTime))
        : 'No buses';
    final arrivalColor =
        (soonest != null &&
            (soonest.arrivalTime == 'Arr' || (soonestMinutes ?? 99) <= 2))
        ? AppTheme.primary
        : AppTheme.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppTheme.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stopName,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('Bus Stop', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  arrivalText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: arrivalColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (soonest != null) ...[
                  const SizedBox(height: 2),
                  Text('Bus ${soonest.name}', style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing16),
          child: Container(height: 1, color: AppTheme.borderDark),
        ),
        if (shuttles.isNotEmpty)
          Wrap(
            spacing: AppTheme.spacing8,
            runSpacing: AppTheme.spacing8,
            children: shuttles.map((s) {
              final eta = s.arrivalTime == 'Arr'
                  ? 'Arr'
                  : (int.tryParse(s.arrivalTime) != null
                        ? '${s.arrivalTime}m'
                        : s.arrivalTime);
              return Container(
                key: ValueKey('badge_${s.name}'),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing8,
                  vertical: AppTheme.spacing4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppTheme.spacing4),
                ),
                child: Text(
                  '${s.name} \u2022 $eta',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              );
            }).toList(),
          )
        else
          Text('Loading routes\u2026', style: theme.textTheme.bodySmall),
      ],
    );
  }
}
