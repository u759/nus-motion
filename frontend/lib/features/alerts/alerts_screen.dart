import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/alerts/widgets/weather_card.dart';
import 'package:frontend/features/alerts/widgets/disruption_card.dart';
import 'package:frontend/features/alerts/widgets/saved_stop_alert_card.dart';

enum _AlertTab { all, service, weather, personal }

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  _AlertTab _activeTab = _AlertTab.all;
  Timer? _alertRefreshTimer;
  Timer? _weatherRefreshTimer;

  // NUS Kent Ridge campus coordinates
  static const _campusLat = 1.2966;
  static const _campusLng = 103.7764;

  @override
  void initState() {
    super.initState();
    _alertRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!mounted) return;
      ref.invalidate(announcementsProvider);
      ref.invalidate(tickerTapesProvider);
      final stops = ref.read(favoriteStopsProvider);
      for (final stopName in stops) {
        ref.invalidate(shuttlesProvider(stopName));
      }
    });
    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (!mounted) return;
      ref.invalidate(weatherProvider((lat: _campusLat, lng: _campusLng)));
    });
  }

  @override
  void dispose() {
    _alertRefreshTimer?.cancel();
    _weatherRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final weatherAsync = ref.watch(
      weatherProvider((lat: _campusLat, lng: _campusLng)),
    );
    final announcementsAsync = ref.watch(announcementsProvider);
    final tickerTapesAsync = ref.watch(tickerTapesProvider);
    final favoriteStops = ref.watch(favoriteStopsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.primary,
              backgroundColor: AppTheme.neutralDark,
              onRefresh: () async {
                ref.invalidate(announcementsProvider);
                ref.invalidate(tickerTapesProvider);
                ref.invalidate(
                  weatherProvider((lat: _campusLat, lng: _campusLng)),
                );
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing16,
                ).copyWith(bottom: 100, top: AppTheme.spacing16),
                children: [
                  // ── Weather Forecast ───────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.weather) ...[
                    _buildSectionHeader(
                      context,
                      'WEATHER FORECAST',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Live Radar',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.primary,
                                ),
                          ),
                          const SizedBox(width: AppTheme.spacing4),
                          const Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing12),
                    weatherAsync.when(
                      data: (weather) => WeatherCard(weather: weather),
                      loading: () => _buildShimmerPlaceholder(180),
                      error: (_, _) =>
                          _buildErrorCard(context, 'Weather unavailable'),
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                  ],

                  // ── Active Disruptions ─────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.service) ...[
                    _buildSectionHeader(context, 'ACTIVE DISRUPTIONS'),
                    const SizedBox(height: AppTheme.spacing12),
                    _buildDisruptions(
                      context,
                      announcementsAsync,
                      tickerTapesAsync,
                    ),
                    const SizedBox(height: AppTheme.spacing24),
                  ],

                  // ── Trip Reminders ─────────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.personal) ...[
                    _buildSectionHeader(context, 'TRIP REMINDERS'),
                    const SizedBox(height: AppTheme.spacing12),
                    _buildTripReminder(context),
                    const SizedBox(height: AppTheme.spacing24),
                  ],

                  // ── Saved Stops ────────────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.personal) ...[
                    _buildSectionHeader(context, 'SAVED STOPS'),
                    const SizedBox(height: AppTheme.spacing12),
                    if (favoriteStops.isEmpty)
                      _buildEmptyCard(context, 'No saved stops'),
                    ...favoriteStops.map(
                      (stopName) => Padding(
                        key: ValueKey('alert_stop_$stopName'),
                        padding: const EdgeInsets.only(
                          bottom: AppTheme.spacing12,
                        ),
                        child: SavedStopAlertCard(stopName: stopName),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header with tabs ────────────────────────────────────────────

  Widget _buildHeader() {
    final theme = Theme.of(context);
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.8),
            border: const Border(
              bottom: BorderSide(color: AppTheme.surfaceVariant),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                    vertical: AppTheme.spacing12,
                  ),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).maybePop(),
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.arrow_back,
                              color: AppTheme.textPrimary,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppTheme.spacing12),
                      Expanded(
                        child: Text(
                          'Alerts & Notifications',
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {},
                          customBorder: const CircleBorder(),
                          child: const SizedBox(
                            width: 40,
                            height: 40,
                            child: Icon(
                              Icons.settings,
                              color: AppTheme.textPrimary,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacing16,
                  ),
                  child: Row(
                    children: _AlertTab.values.map((tab) {
                      final isActive = _activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: AppTheme.spacing24,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _activeTab = tab);
                            },
                            child: Container(
                              padding: const EdgeInsets.only(
                                bottom: AppTheme.spacing12,
                                top: AppTheme.spacing4,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: isActive
                                        ? AppTheme.primary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: AnimatedDefaultTextStyle(
                                duration: AppTheme.durationFast,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isActive
                                      ? AppTheme.primary
                                      : AppTheme.textMuted,
                                ),
                                child: Text(_tabLabel(tab)),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _tabLabel(_AlertTab tab) {
    switch (tab) {
      case _AlertTab.all:
        return 'All';
      case _AlertTab.service:
        return 'Service';
      case _AlertTab.weather:
        return 'Weather';
      case _AlertTab.personal:
        return 'Personal';
    }
  }

  // ── Section header ──────────────────────────────────────────────

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    return Row(
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  // ── Disruptions ─────────────────────────────────────────────────

  Widget _buildDisruptions(
    BuildContext context,
    AsyncValue<List<dynamic>> announcementsAsync,
    AsyncValue<List<dynamic>> tickerTapesAsync,
  ) {
    return announcementsAsync.when(
      data: (announcements) {
        final tickerTapes = tickerTapesAsync.valueOrNull ?? [];
        final cards = <Widget>[];

        for (final a in announcements) {
          final isHigh =
              a.priority.toLowerCase() == 'high' ||
              a.priority.toLowerCase() == 'urgent';
          cards.add(
            Padding(
              key: ValueKey('ann_${a.hashCode}'),
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: DisruptionCard(
                badge: isHigh ? 'Delay' : 'Info',
                meta: a.affectedServiceIds.isNotEmpty
                    ? 'Line ${a.affectedServiceIds} \u2022 ${a.status}'
                    : a.status,
                title: a.text.length > 60 ? a.text.substring(0, 60) : a.text,
                description: a.text,
                priority: a.priority,
              ),
            ),
          );
        }

        for (final t in tickerTapes) {
          final isHigh =
              t.priority.toLowerCase() == 'high' ||
              t.priority.toLowerCase() == 'urgent';
          cards.add(
            Padding(
              key: ValueKey('ticker_${t.hashCode}'),
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: DisruptionCard(
                badge: isHigh ? 'Delay' : 'Info',
                meta: t.affectedServiceIds.isNotEmpty
                    ? 'Line ${t.affectedServiceIds} \u2022 ${t.status}'
                    : t.status,
                title: t.message.length > 60
                    ? t.message.substring(0, 60)
                    : t.message,
                description: t.message,
                priority: t.priority,
              ),
            ),
          );
        }

        if (cards.isEmpty) {
          return _buildEmptyCard(context, 'No active disruptions');
        }

        return Column(children: cards);
      },
      loading: () => _buildShimmerPlaceholder(100),
      error: (_, _) => _buildErrorCard(context, 'Could not load disruptions'),
    );
  }

  // ── Trip reminder (placeholder) ─────────────────────────────────

  Widget _buildTripReminder(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.alarm, color: AppTheme.primary, size: 24),
          ),
          const SizedBox(width: AppTheme.spacing16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave in 5 minutes',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'CS2103L Tutorial @ COM3-0121',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppTheme.textSecondary,
            size: 24,
          ),
        ],
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────

  Widget _buildShimmerPlaceholder(double height) {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.neutralDark,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Center(
        child: Text(message, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
