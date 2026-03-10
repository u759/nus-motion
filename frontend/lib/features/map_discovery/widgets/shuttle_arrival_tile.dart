import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/shuttle.dart';
import 'package:frontend/features/map_discovery/widgets/capacity_indicator.dart';

class ShuttleArrivalTile extends StatelessWidget {
  final Shuttle shuttle;

  const ShuttleArrivalTile({super.key, required this.shuttle});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final eta = EtaFormatter.format(shuttle.arrivalTime);
    final nextEta = EtaFormatter.format(shuttle.nextArrivalTime);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          RouteBadge(routeCode: shuttle.name),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Text(
                  eta,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: eta == 'Arriving' ? colors.success : colors.primary,
                  ),
                ),
                if (nextEta != 'N/A') ...[
                  const SizedBox(width: 6),
                  Text(
                    '• $nextEta',
                    style: TextStyle(fontSize: 13, color: colors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (shuttle.towards != null)
            Text(
              shuttle.towards!,
              style: TextStyle(fontSize: 12, color: colors.textSecondary),
            ),
          if (shuttle.towards != null) const SizedBox(width: 8),
          CapacityIndicator(passengers: shuttle.passengers),
        ],
      ),
    );
  }
}
