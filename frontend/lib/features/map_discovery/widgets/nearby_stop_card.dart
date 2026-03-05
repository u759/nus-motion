import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/distance_formatter.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/widgets/shuttle_arrival_tile.dart';

class NearbyStopCard extends ConsumerWidget {
  final NearbyStopResult stop;

  const NearbyStopCard({super.key, required this.stop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttles = ref.watch(shuttlesProvider(stop.stopName));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.infoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.directions_bus,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.stopDisplayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${DistanceFormatter.format(stop.distanceMeters)} • ${stop.walkingMinutes} min walk',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  ref
                          .watch(favoriteStopsProvider.notifier)
                          .isFavorite(stop.stopName)
                      ? Icons.bookmark
                      : Icons.bookmark_border,
                  color:
                      ref
                          .watch(favoriteStopsProvider.notifier)
                          .isFavorite(stop.stopName)
                      ? AppColors.primary
                      : AppColors.textMuted,
                  size: 22,
                ),
                onPressed: () => ref
                    .read(favoriteStopsProvider.notifier)
                    .toggle(stop.stopName),
              ),
            ],
          ),
          const SizedBox(height: 12),
          shuttles.when(
            data: (result) {
              if (result.shuttles.isEmpty) {
                return const Text(
                  'No services at this time',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                );
              }
              return Column(
                children: result.shuttles
                    .take(4)
                    .map((s) => ShuttleArrivalTile(shuttle: s))
                    .toList(),
              );
            },
            loading: () => const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Text(
              'Failed to load arrivals',
              style: TextStyle(fontSize: 13, color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
