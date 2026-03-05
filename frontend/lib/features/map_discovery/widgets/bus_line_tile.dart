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
      return _buildCollapsedRow(context);
    }
    return _buildExpandedTile(context);
  }

  Widget _buildCollapsedRow(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing8,
        vertical: AppTheme.spacing8,
      ),
      child: Row(
        children: [
          _RouteBadge(code: routeName, filled: false),
          const SizedBox(width: AppTheme.spacing12),
          Expanded(
            child: Text(shuttle.name, style: theme.textTheme.bodyMedium),
          ),
          Text(
            formatEta(shuttle.arrivalTime),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedTile(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(AppTheme.spacing12),
      child: Column(
        children: [
          Row(
            children: [
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onRouteTap,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: _RouteBadge(code: routeName, filled: true),
                ),
              ),
              const SizedBox(width: AppTheme.spacing12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shuttle.name, style: theme.textTheme.titleSmall),
                    if (shuttle.arrivalTimeVehPlate.isNotEmpty)
                      Text(
                        shuttle.arrivalTimeVehPlate,
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatEta(shuttle.arrivalTime),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Next: ${formatEta(shuttle.nextArrivalTime)}',
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing12),
          _buildCapacityBar(),
        ],
      ),
    );
  }

  Widget _buildCapacityBar() {
    if (loadInfo != null) {
      final segments = (loadInfo!.occupancy * 10).round().clamp(0, 10);
      return CapacityBar(filledSegments: segments);
    }
    return CapacityBar.fromPassengers(shuttle.passengers);
  }
}

class _RouteBadge extends StatelessWidget {
  final String code;
  final bool filled;

  const _RouteBadge({required this.code, required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      width: 32,
      decoration: BoxDecoration(
        color: filled ? AppTheme.primary : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      alignment: Alignment.center,
      child: Text(
        code,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: filled ? AppTheme.backgroundDark : AppTheme.textSecondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
