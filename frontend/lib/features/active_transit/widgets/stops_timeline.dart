import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class StopsTimeline extends StatelessWidget {
  final List<String> stops;
  final int currentIndex;
  final String destination;
  final VoidCallback? onStopAdvance;

  const StopsTimeline({
    super.key,
    required this.stops,
    required this.currentIndex,
    required this.destination,
    this.onStopAdvance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text(
              'Stops',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          for (int i = 0; i < stops.length; i++)
            _TimelineStop(
              name: stops[i],
              isPassed: i < currentIndex,
              isCurrent: i == currentIndex,
              isDestination: i == stops.length - 1,
              isLast: i == stops.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineStop extends StatelessWidget {
  final String name;
  final bool isPassed;
  final bool isCurrent;
  final bool isDestination;
  final bool isLast;

  const _TimelineStop({
    required this.name,
    required this.isPassed,
    required this.isCurrent,
    required this.isDestination,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final Color dotColor;
    final bool filled;

    if (isPassed) {
      dotColor = AppColors.primary;
      filled = true;
    } else if (isCurrent) {
      dotColor = AppColors.primary;
      filled = false;
    } else if (isDestination) {
      dotColor = AppColors.primary;
      filled = true;
    } else {
      dotColor = AppColors.textMuted;
      filled = false;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: filled ? dotColor : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: dotColor, width: 2),
                  ),
                  child: isDestination
                      ? Icon(
                          Icons.flag,
                          size: 9,
                          color: filled ? Colors.white : dotColor,
                        )
                      : null,
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: isPassed ? AppColors.primary : AppColors.border,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent)
                    Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.infoBg,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'APPROACHING',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrent || isDestination
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isPassed && !isCurrent
                          ? AppColors.textMuted
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
