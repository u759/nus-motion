import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/alerts/widgets/alert_card.dart';
import 'package:frontend/features/alerts/widgets/staggered_list_item.dart';
import 'package:frontend/features/alerts/widgets/weather_card.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(announcementsProvider);
      ref.invalidate(tickerTapesProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcements = ref.watch(announcementsProvider);
    final tickerTapes = ref.watch(tickerTapesProvider);
    final weather = ref.watch(
      weatherProvider((
        lat: AppConstants.nusLatitude,
        lng: AppConstants.nusLongitude,
      )),
    );
    final colors = context.nusColors;

    return Scaffold(
      backgroundColor: colors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: false,
            backgroundColor: colors.surface,
            title: Text(
              'Transit Alerts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            centerTitle: false,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(52),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: colors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: colors.primary,
                  indicatorWeight: 2,
                  labelColor: colors.primary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelColor: colors.textMuted,
                  unselectedLabelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  tabs: const [
                    Tab(text: 'All'),
                    Tab(text: 'Service Updates'),
                    Tab(text: 'Maintenance'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // All tab
            _AlertsList(
              announcements: announcements,
              tickerTapes: tickerTapes,
              weather: weather,
              filter: null,
              onRetryAnnouncements: () => ref.invalidate(announcementsProvider),
            ),
            // Service Updates tab
            _AlertsList(
              announcements: announcements,
              tickerTapes: tickerTapes,
              weather: weather,
              filter: 'service',
              onRetryAnnouncements: () => ref.invalidate(announcementsProvider),
            ),
            // Maintenance tab
            _AlertsList(
              announcements: announcements,
              tickerTapes: tickerTapes,
              weather: weather,
              onRetryAnnouncements: () => ref.invalidate(announcementsProvider),
              filter: 'maintenance',
            ),
          ],
        ),
      ),
    );
  }
}

class _AlertsList extends StatelessWidget {
  final AsyncValue<List<Announcement>> announcements;
  final AsyncValue<List<TickerTape>> tickerTapes;
  final AsyncValue weather;
  final String? filter;
  final VoidCallback? onRetryAnnouncements;

  const _AlertsList({
    required this.announcements,
    required this.tickerTapes,
    required this.weather,
    this.filter,
    this.onRetryAnnouncements,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Weather card (only on All tab)
        if (filter == null)
          weather.when(
            data: (w) => WeatherCard(weather: w),
            loading: () => const LoadingShimmer(height: 80),
            error: (_, __) => const SizedBox.shrink(),
          ),
        if (filter == null) const SizedBox(height: 16),

        // Live updates (ticker tapes) — right under weather, only on All tab
        tickerTapes.when(
          data: (tapes) {
            if (tapes.isEmpty || filter != null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Updates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.nusColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                ...tapes.map((t) => _TickerCard(key: ValueKey(t.id), tape: t)),
                const SizedBox(height: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),

        // Current Alerts
        announcements.when(
          data: (items) {
            var filtered = items;
            if (filter == 'service') {
              // Service updates: delays, suspensions, disruptions
              filtered = items.where((a) {
                final t = a.text.toLowerCase();
                return t.contains('delay') ||
                    t.contains('suspend') ||
                    t.contains('service') ||
                    t.contains('disruption') ||
                    t.contains('cancelled');
              }).toList();
            } else if (filter == 'maintenance') {
              // Maintenance: construction, road works, scheduled works
              filtered = items.where((a) {
                final t = a.text.toLowerCase();
                return t.contains('maintenance') ||
                    t.contains('road') ||
                    t.contains('construction') ||
                    t.contains('repair') ||
                    t.contains('upgrade');
              }).toList();
            }

            final current = filtered
                .where((a) => a.status.toLowerCase() != 'resolved')
                .toList();
            final past = filtered
                .where((a) => a.status.toLowerCase() == 'resolved')
                .toList();

            if (current.isEmpty && past.isEmpty) {
              return const EmptyState(
                icon: Icons.check_circle_outline,
                title: 'No alerts',
                subtitle: 'All services running normally',
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (current.isNotEmpty) ...[
                  Row(
                    children: [
                      Text(
                        'Current',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.nusColors.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: context.nusColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${current.length} new',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...current.asMap().entries.map(
                    (e) => StaggeredListItem(
                      key: ValueKey(e.value.id),
                      index: e.key,
                      child: AlertCard(announcement: e.value),
                    ),
                  ),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Past',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.nusColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...past.asMap().entries.map(
                    (e) => StaggeredListItem(
                      key: ValueKey(e.value.id),
                      index: e.key + current.length,
                      child: Opacity(
                        opacity: 0.6,
                        child: AlertCard(
                          announcement: e.value,
                          isResolved: true,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const ShimmerList(itemCount: 3, itemHeight: 90),
          error: (error, _) => ErrorCard(
            message: 'Failed to load alerts',
            onRetry: onRetryAnnouncements,
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _TickerCard extends StatelessWidget {
  final TickerTape tape;
  const _TickerCard({super.key, required this.tape});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: colors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tape.message,
              style: TextStyle(fontSize: 13, color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
