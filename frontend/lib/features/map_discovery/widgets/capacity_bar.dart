import 'package:flutter/material.dart';

import 'package:frontend/app/theme.dart';

class CapacityBar extends StatelessWidget {
  final int? filledSegments;

  const CapacityBar({super.key, required this.filledSegments});

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

  Color _segmentColor(int segments) {
    if (segments <= 3) return AppTheme.success;
    if (segments <= 6) return AppTheme.warning;
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final filled = filledSegments;
    final hasData = filled != null;
    final segments = filled ?? 0;
    final percentage = (segments * 10).clamp(0, 100);
    final activeColor = hasData ? _segmentColor(segments) : AppTheme.primary;

    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(10, (i) {
              return Expanded(
                child: AnimatedContainer(
                  duration: AppTheme.durationMedium,
                  curve: AppTheme.curve,
                  height: 6,
                  margin: EdgeInsets.only(right: i < 9 ? 3 : 0),
                  decoration: BoxDecoration(
                    color: hasData && i < segments
                        ? activeColor
                        : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: AppTheme.spacing12),
        Text(
          hasData ? '$percentage% full' : 'N/A',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: hasData ? activeColor : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }
}
