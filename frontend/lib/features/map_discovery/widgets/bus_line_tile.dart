import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/data/models/active_bus.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/features/map_discovery/widgets/capacity_bar.dart';

class BusLineTile extends StatelessWidget {
  final Shuttle shuttle;
  final String routeName;
  final bool expanded;
  final VoidCallback? onRouteTap;
  final LoadInfo? loadInfo;

  const BusLineTile({
    super.key,
    required this.shuttle,
    required this.routeName,
    this.expanded = true,
    this.onRouteTap,
    this.loadInfo,
  });

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return _buildCollapsedRow();
    }
    return _buildExpandedTile();
  }

  Widget _buildCollapsedRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          _routeBadge(
            bgColor: const Color(0xFF334155),
            textColor: const Color(0xFFCBD5E1),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              shuttle.name,
              style: const TextStyle(fontSize: 14, color: Color(0xFFCBD5E1)),
            ),
          ),
          Text(
            formatEta(shuttle.arrivalTime),
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTile() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onRouteTap,
                child: _routeBadge(
                  bgColor: AppTheme.primary,
                  textColor: AppTheme.backgroundDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shuttle.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    if (shuttle.arrivalTimeVehPlate.isNotEmpty)
                      Text(
                        shuttle.arrivalTimeVehPlate,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatEta(shuttle.arrivalTime),
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'NEXT: ${formatEta(shuttle.nextArrivalTime)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF64748B),
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCapacityBar(),
        ],
      ),
    );
  }

  Widget _buildCapacityBar() {
    if (loadInfo != null) {
      // Use real occupancy data from ActiveBus API
      final segments = (loadInfo!.occupancy * 10).round().clamp(0, 10);
      return CapacityBar(filledSegments: segments);
    }
    // Fall back to shuttle passengers field (usually "-")
    return CapacityBar.fromPassengers(shuttle.passengers);
  }

  Widget _routeBadge({required Color bgColor, required Color textColor}) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(
        routeName,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}
