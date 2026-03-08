import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:url_launcher/url_launcher.dart';

class AlertCard extends StatefulWidget {
  final Announcement announcement;
  final bool isResolved;

  const AlertCard({
    super.key,
    required this.announcement,
    this.isResolved = false,
  });

  @override
  State<AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends State<AlertCard>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late final AnimationController _iconController;
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _iconController.dispose();
    for (final r in _recognizers) {
      r.dispose();
    }
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _iconController.forward();
      } else {
        _iconController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final (Color bgColor, Color iconColor, IconData icon) = _resolveStyle();
    final text = widget.announcement.text;
    final needsExpand = text.length > 120;

    return GestureDetector(
      onTap: needsExpand ? _toggleExpanded : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: widget.isResolved ? AppColors.surfaceMuted : AppColors.surface,
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
                        child: Text.rich(
                          TextSpan(children: _parseHtmlLinks(_extractTitle())),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (widget.announcement.affectedServiceIds.isNotEmpty)
                        Text(
                          widget.announcement.affectedServiceIds,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                    ],
                  ),
                  // Show date/time if available
                  if (widget.announcement.createdOn != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      _formatDate(widget.announcement.createdOn!),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  AnimatedCrossFade(
                    firstChild: _buildRichText(text, maxLines: 3),
                    secondChild: _buildRichText(text, maxLines: null),
                    crossFadeState: _isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                    duration: const Duration(milliseconds: 200),
                    sizeCurve: Curves.easeInOut,
                  ),
                  if (needsExpand) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        RotationTransition(
                          turns: Tween(begin: 0.0, end: 0.5)
                              .animate(_iconController),
                          child: Icon(
                            Icons.expand_more,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isExpanded ? 'Show less' : 'Show more',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRichText(String text, {int? maxLines}) {
    final spans = _parseHtmlLinks(text);
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(
        fontSize: 13,
        color: AppColors.textSecondary,
      ),
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : TextOverflow.clip,
    );
  }

  /// Parses <a href="url">text</a> tags into tappable links
  List<InlineSpan> _parseHtmlLinks(String text) {
    final spans = <InlineSpan>[];
    final regex = RegExp(r'<a\s+href="([^"]+)"[^>]*>([^<]+)</a>');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add text before the link
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      // Add the clickable link
      final url = match.group(1)!;
      final linkText = match.group(2)!;
      final recognizer = TapGestureRecognizer()..onTap = () => _launchUrl(url);
      _recognizers.add(recognizer);
      spans.add(
        TextSpan(
          text: linkText,
          style: const TextStyle(
            color: AppColors.primary,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.primary,
          ),
          recognizer: recognizer,
        ),
      );
      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    // If no links found, return original text
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }

    return spans;
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${_monthName(date.month)} ${date.day} at ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
  }

  String _monthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  (Color, Color, IconData) _resolveStyle() {
    if (widget.isResolved) {
      return (AppColors.mutedBg, AppColors.textMuted, Icons.check_circle);
    }
    final p = widget.announcement.priority.toLowerCase();
    final t = widget.announcement.text.toLowerCase();
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
    final text = widget.announcement.text;
    if (text.length <= 60) return text;
    final dot = text.indexOf('.');
    if (dot > 0 && dot <= 60) return text.substring(0, dot);
    return '${text.substring(0, 57)}...';
  }
}
