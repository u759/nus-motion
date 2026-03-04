import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
                  horizontal: 16,
                ).copyWith(bottom: 100, top: 16),
                children: [
                  // ── Weather Forecast ───────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.weather) ...[
                    _buildSectionHeader(
                      'WEATHER FORECAST',
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Live Radar',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.open_in_new,
                            size: 12,
                            color: AppTheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    weatherAsync.when(
                      data: (weather) => WeatherCard(weather: weather),
                      loading: () => _buildLoadingPlaceholder(180),
                      error: (_, _) => _buildErrorCard('Weather unavailable'),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ── Active Disruptions ─────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.service) ...[
                    _buildSectionHeader('ACTIVE DISRUPTIONS'),
                    const SizedBox(height: 12),
                    _buildDisruptions(announcementsAsync, tickerTapesAsync),
                    const SizedBox(height: 24),
                  ],

                  // ── Trip Reminders ─────────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.personal) ...[
                    _buildSectionHeader('TRIP REMINDERS'),
                    const SizedBox(height: 12),
                    _buildTripReminder(),
                    const SizedBox(height: 24),
                  ],

                  // ── Saved Stops ────────────────────────────
                  if (_activeTab == _AlertTab.all ||
                      _activeTab == _AlertTab.personal) ...[
                    _buildSectionHeader('SAVED STOPS'),
                    const SizedBox(height: 12),
                    if (favoriteStops.isEmpty)
                      _buildEmptyCard('No saved stops'),
                    ...favoriteStops.map(
                      (stopName) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
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
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundDark.withValues(alpha: 0.8),
            border: const Border(bottom: BorderSide(color: Color(0xFF1E293B))),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Title row
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).maybePop(),
                        child: const Icon(
                          Icons.arrow_back,
                          color: AppTheme.textPrimary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Alerts & Notifications',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.3,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      GestureDetector(
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.settings,
                            color: AppTheme.textPrimary,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Tab bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: _AlertTab.values.map((tab) {
                      final isActive = _activeTab == tab;
                      return Padding(
                        padding: const EdgeInsets.only(right: 24),
                        child: GestureDetector(
                          onTap: () => setState(() => _activeTab = tab),
                          child: Container(
                            padding: const EdgeInsets.only(bottom: 12, top: 4),
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
                            child: Text(
                              _tabLabel(tab),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isActive
                                    ? AppTheme.primary
                                    : AppTheme.textMuted,
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

  Widget _buildSectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: AppTheme.textMuted,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  // ── Disruptions ─────────────────────────────────────────────────

  Widget _buildDisruptions(
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
              padding: const EdgeInsets.only(bottom: 12),
              child: DisruptionCard(
                badge: isHigh ? 'Delay' : 'Info',
                meta: a.affectedServiceIds.isNotEmpty
                    ? 'Line ${a.affectedServiceIds} • ${a.status}'
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
              padding: const EdgeInsets.only(bottom: 12),
              child: DisruptionCard(
                badge: isHigh ? 'Delay' : 'Info',
                meta: t.affectedServiceIds.isNotEmpty
                    ? 'Line ${t.affectedServiceIds} • ${t.status}'
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
          return _buildEmptyCard('No active disruptions');
        }

        return Column(children: cards);
      },
      loading: () => _buildLoadingPlaceholder(100),
      error: (_, _) => _buildErrorCard('Could not load disruptions'),
    );
  }

  // ── Trip reminder (placeholder) ─────────────────────────────────

  Widget _buildTripReminder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
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
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leave in 5 minutes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'CS2103L Tutorial @ COM3-0121',
                  style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
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

  Widget _buildLoadingPlaceholder(double height) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ),
    );
  }
}
