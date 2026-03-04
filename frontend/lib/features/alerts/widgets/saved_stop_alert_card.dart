import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final shuttlesAsync = ref.watch(shuttlesProvider(stopName));

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        children: [
          // ── Header ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stopName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (stopId != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'STOP ID: $stopId',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            color: AppTheme.textMuted,
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
          Container(height: 1, color: const Color(0xFF1E293B)),
          // ── Bus rows ───────────────────────────────────────
          shuttlesAsync.when(
            data: (result) => _buildShuttleRows(result.shuttles),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ),
            error: (_, _) => const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Unable to load arrivals',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShuttleRows(List<Shuttle> shuttles) {
    if (shuttles.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No active services',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < shuttles.length; i++) ...[
          if (i > 0) Container(height: 1, color: const Color(0xFF1E293B)),
          _ShuttleRow(shuttle: shuttles[i]),
        ],
      ],
    );
  }
}

class _ShuttleRow extends StatelessWidget {
  final Shuttle shuttle;

  const _ShuttleRow({required this.shuttle});

  @override
  Widget build(BuildContext context) {
    final etaText = formatEta(shuttle.arrivalTime);
    final nextEta = formatEta(shuttle.nextArrivalTime);
    final isDelayed = (int.tryParse(shuttle.arrivalTime) ?? 0) > 10;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Route badge
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: Text(
              shuttle.name,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Destination + status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shuttle.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                if (isDelayed)
                  Row(
                    children: [
                      Icon(
                        Icons.warning,
                        size: 12,
                        color: const Color(0xFFFFBF00),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Delayed',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFFFBF00),
                        ),
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'On Time',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // ETA
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                etaText,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDelayed
                      ? const Color(0xFFFFBF00)
                      : AppTheme.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Following: $nextEta',
                style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
