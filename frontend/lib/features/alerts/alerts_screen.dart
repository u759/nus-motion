import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/widgets/loading_shimmer.dart';
import 'package:frontend/core/widgets/error_card.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/utils/weather_mapper.dart';
import 'package:frontend/data/models/announcement.dart';
import 'package:frontend/data/models/ticker_tape.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/alerts/widgets/alert_card.dart';
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
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxScrolled) => [
          SliverAppBar(
            pinned: true,
            floating: true,
            backgroundColor: AppColors.surface,
            title: const Text(
              'Transit Alerts',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.search, color: AppColors.textSecondary),
                onPressed: () {},
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2,
                  labelColor: AppColors.primary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelColor: AppColors.textMuted,
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
            ),
            // Service Updates tab
            _AlertsList(
              announcements: announcements,
              tickerTapes: tickerTapes,
              weather: weather,
              filter: 'service',
            ),
            // Maintenance tab
            _AlertsList(
              announcements: announcements,
              tickerTapes: tickerTapes,
              weather: weather,
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

  const _AlertsList({
    required this.announcements,
    required this.tickerTapes,
    required this.weather,
    this.filter,
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

        // Current Alerts
        announcements.when(
          data: (items) {
            var filtered = items;
            if (filter == 'service') {
              filtered = items
                  .where(
                    (a) =>
                        a.priority.toLowerCase().contains('high') ||
                        a.status.toLowerCase() == 'active',
                  )
                  .toList();
            } else if (filter == 'maintenance') {
              filtered = items
                  .where(
                    (a) =>
                        a.priority.toLowerCase().contains('low') ||
                        a.text.toLowerCase().contains('maintenance'),
                  )
                  .toList();
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
                      const Text(
                        'CURRENT ALERTS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMuted,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${current.length} NEW',
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
                  ...current.map(
                    (a) => AlertCard(key: ValueKey(a.id), announcement: a),
                  ),
                ],
                if (past.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'PAST ALERTS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMuted,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...past.map(
                    (a) => Opacity(
                      key: ValueKey(a.id),
                      opacity: 0.6,
                      child: AlertCard(announcement: a, isResolved: true),
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const ShimmerList(itemCount: 3, itemHeight: 90),
          error: (error, _) => ErrorCard(message: error.toString()),
        ),

        // Ticker tapes
        tickerTapes.when(
          data: (tapes) {
            if (tapes.isEmpty || filter != null) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                const Text(
                  'LIVE UPDATES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                ...tapes.map(
                  (t) => _TickerCard(key: ValueKey(t.message), tape: t),
                ),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tape.message,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
