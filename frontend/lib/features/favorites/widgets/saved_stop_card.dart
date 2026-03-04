import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.redAccent),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: shuttlesAsync.when(
          data: (result) => _buildContent(result.shuttles),
          loading: () => _buildContent([]),
          error: (_, _) => _buildContent([]),
        ),
      ),
    );
  }

  Widget _buildContent(List<Shuttle> shuttles) {
    // Find the soonest arriving shuttle
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
        : const Color(0xFFCBD5E1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Location icon
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.location_on,
                color: AppTheme.textSecondary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            // Stop name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stopName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Bus Stop',
                    style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ),
            // Arrival info
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  arrivalText,
                  style: TextStyle(
                    color: arrivalColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (soonest != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Bus ${soonest.name}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        // Divider
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.05),
          ),
        ),
        // Route ETA badges
        if (shuttles.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: shuttles.map((s) {
              final eta = s.arrivalTime == 'Arr'
                  ? 'Arr'
                  : (int.tryParse(s.arrivalTime) != null
                        ? '${s.arrivalTime}m'
                        : s.arrivalTime);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${s.name} • $eta',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFCBD5E1),
                  ),
                ),
              );
            }).toList(),
          )
        else
          const Text(
            'Loading routes…',
            style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
          ),
      ],
    );
  }
}
