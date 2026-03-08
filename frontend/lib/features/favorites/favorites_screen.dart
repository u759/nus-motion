import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/utils/eta_formatter.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/state/providers.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      // Invalidate shuttle providers for visible favorite stops
      for (final stop in ref.read(favoriteStopsProvider)) {
        ref.invalidate(shuttlesProvider(stop));
      }
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoriteStops = ref.watch(favoriteStopsProvider);
    final favoriteRoutes = ref.watch(favoriteRoutesProvider);
    final recentSearches = ref.watch(recentSearchesProvider);

    final hasContent =
        favoriteStops.isNotEmpty ||
        favoriteRoutes.isNotEmpty ||
        recentSearches.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Saved',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Favorite Stops
                if (favoriteStops.isNotEmpty) ...[
                  const _SectionHeader(title: 'FAVORITE STOPS'),
                  const SizedBox(height: 8),
                  ...favoriteStops.map(
                    (stop) => _FavoriteStopCard(
                      stopName: stop,
                      onDismissed: () =>
                          ref.read(favoriteStopsProvider.notifier).toggle(stop),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Favorite Routes
                if (favoriteRoutes.isNotEmpty) ...[
                  const _SectionHeader(title: 'FAVORITE ROUTES'),
                  const SizedBox(height: 8),
                  ...favoriteRoutes.map(
                    (r) => _FavoriteRouteCard(
                      from: r.from,
                      to: r.to,
                      onTap: () => context.go('/'),
                      onDismissed: () => ref
                          .read(favoriteRoutesProvider.notifier)
                          .toggle(r.from, r.to),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Recent Searches
                if (recentSearches.isNotEmpty) ...[
                  Row(
                    children: [
                      const _SectionHeader(title: 'RECENT SEARCHES'),
                      const Spacer(),
                      TextButton(
                        onPressed: () =>
                            ref.read(recentSearchesProvider.notifier).clear(),
                        child: const Text(
                          'Clear',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...recentSearches.map(
                    (r) => _RecentSearchTile(
                      from: r.from,
                      to: r.to,
                      onTap: () => context.go('/'),
                    ),
                  ),
                ],
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
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
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

    return Dismissible(
      key: ValueKey('stop_$stopName'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () => _navigateToStop(context, ref),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_bus,
                    color: AppColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      stopName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.bookmark, color: AppColors.primary, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              shuttles.when(
                data: (result) {
                  if (result.shuttles.isEmpty) {
                    return const Text(
                      'No services',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
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
                error: (_, __) => const Text(
                  'Unavailable',
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
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
    return Dismissible(
      key: ValueKey('route_${from}_$to'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              const Icon(Icons.route, color: AppColors.primary, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$from → $to',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: AppColors.textMuted, size: 18),
            const SizedBox(width: 12),
            Text(
              '$from → $to',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
