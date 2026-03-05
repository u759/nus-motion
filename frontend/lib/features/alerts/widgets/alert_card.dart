import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/announcement.dart';

class AlertCard extends StatelessWidget {
  final Announcement announcement;
  final bool isResolved;

  const AlertCard({
    super.key,
    required this.announcement,
    this.isResolved = false,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color iconColor, IconData icon) = _resolveStyle();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isResolved ? AppColors.surfaceMuted : AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _extractTitle(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (announcement.affectedServiceIds.isNotEmpty)
                      Text(
                        announcement.affectedServiceIds,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  announcement.text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, Color, IconData) _resolveStyle() {
    if (isResolved) {
      return (AppColors.mutedBg, AppColors.textMuted, Icons.check_circle);
    }
    final p = announcement.priority.toLowerCase();
    final t = announcement.text.toLowerCase();
    if (p.contains('high') ||
        p.contains('critical') ||
        t.contains('delay') ||
        t.contains('suspend')) {
      return (AppColors.errorBg, AppColors.error, Icons.warning);
    }
    if (t.contains('maintenance') || t.contains('road')) {
      return (AppColors.warningBg, AppColors.orange, Icons.settings_suggest);
    }
    return (AppColors.infoBg, AppColors.primary, Icons.info);
  }

  String _extractTitle() {
    final text = announcement.text;
    if (text.length <= 60) return text;
    final dot = text.indexOf('.');
    if (dot > 0 && dot <= 60) return text.substring(0, dot);
    return '${text.substring(0, 57)}...';
  }
}
