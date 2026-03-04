import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';

class CapacityBar extends StatelessWidget {
  /// Number of filled segments out of 10, or null if no data.
  final int? filledSegments;

  const CapacityBar({super.key, required this.filledSegments});

  /// Convert a passenger string ("Low", "Medium", "High", or numeric)
  /// to a 0-10 segment count. Returns null for unknown/missing data.
  factory CapacityBar.fromPassengers(String passengers) {
    final segments = _parsePassengers(passengers);
    return CapacityBar(filledSegments: segments);
  }

  static int? _parsePassengers(String passengers) {
    final trimmed = passengers.trim().toLowerCase();
    switch (trimmed) {
      case 'low':
        return 3;
      case 'medium':
      case 'med':
        return 5;
      case 'high':
        return 8;
      case 'full':
        return 10;
      default:
        final n = int.tryParse(trimmed);
        if (n != null) return n.clamp(0, 10);
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filled = filledSegments;
    final hasData = filled != null;
    final segments = filled ?? 0;
    final percentage = (segments * 10).clamp(0, 100);

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(10, (i) {
              return Expanded(
                child: Container(
                  height: 6,
                  margin: EdgeInsets.only(right: i < 9 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: hasData && i < segments
                        ? AppTheme.primary
                        : const Color(0xFF334155),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          hasData ? '$percentage% FULL' : 'N/A',
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
