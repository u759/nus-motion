import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/favorites/widgets/favorite_route_card.dart';
import 'package:frontend/features/favorites/widgets/saved_stop_card.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  Timer? _shuttleRefreshTimer;
  Timer? _serviceDescRefreshTimer;

  @override
  void initState() {
    super.initState();
    _shuttleRefreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted) return;
      final stops = ref.read(favoriteStopsProvider);
      for (final stopName in stops) {
        ref.invalidate(shuttlesProvider(stopName));
      }
    });
    _serviceDescRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      ref.invalidate(serviceDescriptionsProvider);
    });
  }

  @override
  void dispose() {
    _shuttleRefreshTimer?.cancel();
    _serviceDescRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final favoriteRoutes = ref.watch(favoriteRoutesProvider);
    final favoriteStops = ref.watch(favoriteStopsProvider);
    final serviceDescAsync = ref.watch(serviceDescriptionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: Column(
        children: [
          // ── Glass header ────────────────────────────────────────
          _buildHeader(context),
          // ── Scrollable content ──────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
              ).copyWith(bottom: 100),
              children: [
                // ── Favorite Bus Lines ────────────────────────────
                const SizedBox(height: 32),
                _buildSectionLabel(
                  'FAVORITE BUS LINES',
                  trailing: Text(
                    '${favoriteRoutes.length} active',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (favoriteRoutes.isEmpty)
                  _buildEmptyHint('No favorite bus lines yet')
                else
                  serviceDescAsync.when(
                    data: (descriptions) =>
                        _buildRouteCards(favoriteRoutes, descriptions),
                    loading: () => _buildRouteCards(favoriteRoutes, []),
                    error: (_, _) => _buildRouteCards(favoriteRoutes, []),
                  ),

                // ── Saved Stops ───────────────────────────────────
                const SizedBox(height: 40),
                _buildSectionLabel(
                  'SAVED STOPS',
                  trailing: GestureDetector(
                    onTap: () {
                      // Toggle edit mode (could be expanded later)
                    },
                    child: const Text(
                      'Edit List',
                      style: TextStyle(fontSize: 10, color: AppTheme.primary),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ...favoriteStops.map(
                  (stopName) => Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: SavedStopCard(
                      stopName: stopName,
                      onDismissed: () {
                        ref
                            .read(favoriteStopsProvider.notifier)
                            .remove(stopName);
                      },
                    ),
                  ),
                ),
                // Add new destination card
                _buildAddDestinationCard(context),

                // ── Recent Activity ───────────────────────────────
                const SizedBox(height: 40),
                _buildSectionLabel('RECENT ACTIVITY'),
                const SizedBox(height: 16),
                _buildRecentActivityCard(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.star, color: AppTheme.primary, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Favorites',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.3,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  // Add button
                  GestureDetector(
                    onTap: () => context.go('/search'),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: AppTheme.primary,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────

  Widget _buildSectionLabel(String title, {Widget? trailing}) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: AppTheme.textSecondary,
          ),
        ),
        const Spacer(),
        ?trailing,
      ],
    );
  }

  // ── Route cards list ──────────────────────────────────────────────

  Widget _buildRouteCards(
    List<String> routes,
    List<ServiceDescription> descriptions,
  ) {
    return Column(
      children: routes.map((code) {
        final desc = descriptions
            .where((d) => d.route == code)
            .cast<ServiceDescription?>()
            .firstOrNull;
        return Padding(
          padding: EdgeInsets.only(bottom: code != routes.last ? 12 : 0),
          child: FavoriteRouteCard(routeCode: code, description: desc),
        );
      }).toList(),
    );
  }

  // ── Empty state hint ──────────────────────────────────────────────

  Widget _buildEmptyHint(String text) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
        ),
      ),
    );
  }

  // ── Add destination card ──────────────────────────────────────────

  Widget _buildAddDestinationCard(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/search'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle, color: AppTheme.textMuted, size: 20),
            SizedBox(width: 8),
            Text(
              'Add new destination',
              style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  // ── Recent activity card ──────────────────────────────────────────

  Widget _buildRecentActivityCard() {
    final recentTrips = ref.watch(favoritesRepositoryProvider).getRecentTrips();

    if (recentTrips.isEmpty) {
      // Show placeholder matching the HTML design
      return _buildActivityTile(
        from: 'UTown',
        to: 'Science',
        subtitle: '2 hours ago • Bus D1',
      );
    }

    final trip = recentTrips.first;
    return _buildActivityTile(
      from: trip['from'] ?? '',
      to: trip['to'] ?? '',
      subtitle: trip['time'] ?? 'Recently',
    );
  }

  Widget _buildActivityTile({
    required String from,
    required String to,
    required String subtitle,
  }) {
    return Opacity(
      opacity: 0.6,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          const TextSpan(text: 'Traveled from '),
                          TextSpan(
                            text: from,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                          const TextSpan(text: ' to '),
                          TextSpan(
                            text: to,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Color(0xFFE2E8F0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
