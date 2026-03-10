import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class CapacityIndicator extends StatelessWidget {
  final String passengers;

  const CapacityIndicator({super.key, required this.passengers});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    final level = _parseLevel(passengers);
    final Color color;
    final String label;

    switch (level) {
      case _CrowdLevel.low:
        color = colors.success;
        label = 'Low';
      case _CrowdLevel.medium:
        color = colors.warning;
        label = 'Med';
      case _CrowdLevel.high:
        color = colors.error;
        label = 'Full';
      case _CrowdLevel.unknown:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  static _CrowdLevel _parseLevel(String passengers) {
    if (passengers == '-' || passengers.isEmpty) return _CrowdLevel.unknown;
    final val = int.tryParse(passengers);
    if (val == null) {
      if (passengers.toLowerCase().contains('low')) return _CrowdLevel.low;
      if (passengers.toLowerCase().contains('high') ||
          passengers.toLowerCase().contains('full')) {
        return _CrowdLevel.high;
      }
      return _CrowdLevel.medium;
    }
    if (val < 30) return _CrowdLevel.low;
    if (val < 60) return _CrowdLevel.medium;
    return _CrowdLevel.high;
  }
}

enum _CrowdLevel { low, medium, high, unknown }
