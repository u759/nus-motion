import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/state/providers.dart';

class SavedStopAlertCard extends ConsumerWidget {
  final String stopName;
  final String? stopId;

  const SavedStopAlertCard({super.key, required this.stopName, this.stopId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shuttlesAsync = ref.watch(shuttlesProvider(stopName));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceVariant),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopName,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (stopId != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'STOP ID: $stopId',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.star, color: AppTheme.primary, size: 22),
              ],
            ),
          ),
          Container(height: 1, color: AppTheme.surfaceVariant),
          shuttlesAsync.when(
            data: (result) => _buildShuttleRows(result.shuttles),
            loading: () => _buildShimmerRows(),
            error: (_, _) => Padding(
              padding: const EdgeInsets.all(AppTheme.spacing16),
              child: Text(
                'Unable to load arrivals',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerRows() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.neutralDark,
      child: Column(
        children: List.generate(
          2,
          (i) => Padding(
            padding: const EdgeInsets.all(AppTheme.spacing16),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.spacing4),
                  ),
                ),
                const SizedBox(width: AppTheme.spacing12),
                Expanded(
                  child: Container(
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(AppTheme.spacing4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShuttleRows(List<Shuttle> shuttles) {
    if (shuttles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spacing16),
        child: Builder(
          builder: (context) => Text(
            'No active services',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < shuttles.length; i++) ...[
          if (i > 0) Container(height: 1, color: AppTheme.surfaceVariant),
          _ShuttleRow(
            key: ValueKey('shuttle_${shuttles[i].name}'),
            shuttle: shuttles[i],
          ),
        ],
      ],
    );
  }
}

class _ShuttleRow extends StatelessWidget {
  final Shuttle shuttle;

  const _ShuttleRow({super.key, required this.shuttle});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final etaText = formatEta(shuttle.arrivalTime);
    final nextEta = formatEta(shuttle.nextArrivalTime);
    final isDelayed = (int.tryParse(shuttle.arrivalTime) ?? 0) > 10;

    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(AppTheme.spacing4),
            ),
            alignment: Alignment.center,
            child: Text(
              shuttle.name,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shuttle.name,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (isDelayed)
                  Row(
                    children: [
                      const Icon(
                        Icons.warning,
                        size: 12,
                        color: AppTheme.warning,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        'Delayed',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.warning,
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: AppTheme.spacing4),
                      Text(
                        'On Time',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                etaText,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDelayed ? AppTheme.warning : AppTheme.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text('Following: $nextEta', style: theme.textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
