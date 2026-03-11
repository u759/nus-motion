import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/state/providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      // Invalidate shuttle providers for visible favorite stops
      for (final stop in ref.read(favoriteStopsProvider)) {
        ref.invalidate(shuttlesProvider(stop));
      }
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
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final favoriteStops = ref.watch(favoriteStopsProvider);
    final favoriteRoutes = ref.watch(favoriteRoutesProvider);
    final recentSearches = ref.watch(recentSearchesProvider);
    final colors = context.nusColors;

    final hasContent =
        favoriteStops.isNotEmpty ||
        favoriteRoutes.isNotEmpty ||
        recentSearches.isNotEmpty;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Text(
          'Saved',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: false,
      ),
      body: !hasContent
          ? const EmptyState(
              icon: Icons.bookmark_outline,
              title: 'No saved items yet',
              subtitle: 'Bookmark stops and routes to see them here',
            )
          : CustomScrollView(
              slivers: [
                const SliverPadding(
                  padding: EdgeInsets.only(top: 12),
                  sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                ),

                // Favorite Stops
                if (favoriteStops.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(title: 'Stops'),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: favoriteStops.length,
                      itemBuilder: (context, i) {
                        final stop = favoriteStops[i];
                        return FadeSlideIn(
                          key: ValueKey('fade_stop_$stop'),
                          delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                          child: _FavoriteStopCard(
                            stopName: stop,
                            onDismissed: () => ref
                                .read(favoriteStopsProvider.notifier)
                                .toggle(stop),
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // Favorite Routes
                if (favoriteRoutes.isNotEmpty) ...[
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: _SectionHeader(title: 'Routes'),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: favoriteRoutes.length,
                      itemBuilder: (context, i) {
                        final r = favoriteRoutes[i];
                        return FadeSlideIn(
                          key: ValueKey('fade_route_${r.from}_${r.to}'),
                          delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                          child: _FavoriteRouteCard(
                            from: r.from,
                            to: r.to,
                            onTap: () => context.go('/'),
                            onDismissed: () => ref
                                .read(favoriteRoutesProvider.notifier)
                                .toggle(r.from, r.to),
                          ),
                        );
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],

                // Recent Searches
                if (recentSearches.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const _SectionHeader(title: 'Recents'),
                          const Spacer(),
                          TextButton(
                            onPressed: () => ref
                                .read(recentSearchesProvider.notifier)
                                .clear(),
                            child: Text(
                              'Clear',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 8)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList.builder(
                      itemCount: recentSearches.length,
                      itemBuilder: (context, i) {
                        final r = recentSearches[i];
                        return FadeSlideIn(
                          key: ValueKey('fade_recent_${r.from}_${r.to}'),
                          delay: Duration(milliseconds: 40 * i.clamp(0, 8)),
                          child: _RecentSearchTile(
                            from: r.from,
                            to: r.to,
                            onTap: () => context.go('/'),
                          ),
                        );
                      },
                    ),
                  ),
                ],

                const SliverPadding(
                  padding: EdgeInsets.only(bottom: 16),
                  sliver: SliverToBoxAdapter(child: SizedBox.shrink()),
                ),
              ],
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: colors.textSecondary,
      ),
    );
  }
}

class _FavoriteStopCard extends ConsumerWidget {
  final String stopName;
  final VoidCallback onDismissed;

  const _FavoriteStopCard({required this.stopName, required this.onDismissed});

  void _navigateToStop(BuildContext context, WidgetRef ref) {
    // Set the pending stop selection — MapDiscoveryScreen will pick this up
    ref.read(pendingStopSelectionProvider.notifier).state = stopName;
    // Navigate to Explore tab
    context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shuttles = ref.watch(shuttlesProvider(stopName));
    final colors = context.nusColors;

    return Dismissible(
      key: ValueKey('stop_$stopName'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: PressableScale(
        onTap: () => _navigateToStop(context, ref),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border, width: 0.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.directions_bus, color: colors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stopName,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.bookmark, color: colors.primary, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              shuttles.when(
                data: (result) {
                  if (result.shuttles.isEmpty) {
                    return Text(
                      'No services',
                      style: TextStyle(fontSize: 12, color: colors.textMuted),
                    );
                  }
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: result.shuttles.take(3).map((s) {
                      final eta = EtaFormatter.format(s.arrivalTime);
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          RouteBadge(routeCode: s.name, fontSize: 10),
                          const SizedBox(width: 4),
                          Text(
                            eta,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  );
                },
                loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => Text(
                  'Unavailable',
                  style: TextStyle(fontSize: 12, color: colors.textMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoriteRouteCard extends StatelessWidget {
  final String from;
  final String to;
  final VoidCallback onTap;
  final VoidCallback onDismissed;

  const _FavoriteRouteCard({
    required this.from,
    required this.to,
    required this.onTap,
    required this.onDismissed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return Dismissible(
      key: ValueKey('route_${from}_$to'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: colors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: PressableScale(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.border, width: 0.5),
          ),
          child: Row(
            children: [
              Icon(Icons.route, color: colors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$from → $to',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentSearchTile extends StatelessWidget {
  final String from;
  final String to;
  final VoidCallback onTap;

  const _RecentSearchTile({
    required this.from,
    required this.to,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border, width: 0.5),
        ),
        child: Row(
          children: [
            Icon(Icons.history, color: colors.textMuted, size: 18),
            const SizedBox(width: 12),
            Text(
              '$from → $to',
              style: TextStyle(fontSize: 13, color: colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
