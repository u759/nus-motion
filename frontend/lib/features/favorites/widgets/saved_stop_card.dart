import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/state/providers.dart';

class SavedStopCard extends ConsumerWidget {
  final String stopName;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  const SavedStopCard({
    super.key,
    required this.stopName,
    this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttles = ref.watch(shuttlesProvider(stopName));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
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
                const Icon(
                  Icons.directions_bus,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stopName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (onRemove != null)
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(
                      Icons.bookmark,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            shuttles.when(
              data: (result) {
                if (result.shuttles.isEmpty) {
                  return const Text(
                    'No services available',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  );
                }
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: result.shuttles.take(2).map((s) {
                    final eta = EtaFormatter.format(s.arrivalTime);
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RouteBadge(routeCode: s.name, fontSize: 10),
                        const SizedBox(width: 4),
                        Text(
                          eta,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
              loading: () => const SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Text(
                'Unavailable',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
