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
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 3, vsync: this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      ref.invalidate(announcementsProvider);
      ref.invalidate(tickerTapesProvider);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startPolling();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
    final colors = context.nusColors;

    // Pre-compute filtered announcements data for builder use
    final List<Announcement> current;
    final List<Announcement> past;
    final bool announcementsLoading;
    final bool announcementsError;

    if (announcements case AsyncData(value: final items)) {
      var filtered = items;
      if (filter == 'service') {
        filtered = items.where((a) {
          final t = a.text.toLowerCase();
          return t.contains('delay') ||
              t.contains('suspend') ||
              t.contains('service') ||
              t.contains('disruption') ||
              t.contains('cancelled');
        }).toList();
      } else if (filter == 'maintenance') {
        filtered = items.where((a) {
          final t = a.text.toLowerCase();
          return t.contains('maintenance') ||
              t.contains('road') ||
              t.contains('construction') ||
              t.contains('repair') ||
              t.contains('upgrade');
        }).toList();
      }
      current = filtered
          .where((a) => a.status.toLowerCase() != 'resolved')
          .toList();
      past = filtered
          .where((a) => a.status.toLowerCase() == 'resolved')
          .toList();
      announcementsLoading = false;
      announcementsError = false;
    } else if (announcements is AsyncLoading) {
      current = [];
      past = [];
      announcementsLoading = true;
      announcementsError = false;
    } else {
      current = [];
      past = [];
      announcementsLoading = false;
      announcementsError = true;
    }

    // Pre-compute ticker tapes for builder use
    final List<TickerTape> tapes;
    if (filter == null) {
      tapes = switch (tickerTapes) {
        AsyncData(value: final t) => t,
        _ => <TickerTape>[],
      };
    } else {
      tapes = [];
    }

    return CustomScrollView(
      slivers: [
        // Weather card (only on All tab)
        if (filter == null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: weather.when(
                data: (w) => WeatherCard(weather: w),
                loading: () => const LoadingShimmer(height: 80),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),
          ),
        if (filter == null)
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Live Updates header + ticker cards
        if (tapes.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Live Updates',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: tapes.length,
              itemBuilder: (context, i) =>
                  _TickerCard(key: ValueKey(tapes[i].id), tape: tapes[i]),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // Announcements: loading state
        if (announcementsLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ShimmerList(itemCount: 3, itemHeight: 90),
            ),
          ),

        // Announcements: error state
        if (announcementsError)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ErrorCard(
                message: 'Failed to load alerts',
                onRetry: onRetryAnnouncements,
              ),
            ),
          ),

        // Announcements: empty state
        if (!announcementsLoading &&
            !announcementsError &&
            current.isEmpty &&
            past.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: EmptyState(
                icon: Icons.check_circle_outline,
                title: 'No alerts',
                subtitle: 'All services running normally',
              ),
            ),
          ),

        // Current section header
        if (current.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    'Current',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary,
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
            ),
          ),
        if (current.isNotEmpty)
          const SliverToBoxAdapter(child: SizedBox(height: 12)),

        // Current alerts list (builder)
        if (current.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: current.length,
              itemBuilder: (context, i) => StaggeredListItem(
                key: ValueKey(current[i].id),
                index: i,
                child: AlertCard(announcement: current[i]),
              ),
            ),
          ),

        // Past section header
        if (past.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Past',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],

        // Past alerts list (builder)
        if (past.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: past.length,
              itemBuilder: (context, i) => StaggeredListItem(
                key: ValueKey(past[i].id),
                index: i + current.length,
                child: Opacity(
                  opacity: 0.6,
                  child: AlertCard(announcement: past[i], isResolved: true),
                ),
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
