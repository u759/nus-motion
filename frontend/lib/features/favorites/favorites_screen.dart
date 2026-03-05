import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

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
    final textTheme = Theme.of(context).textTheme;

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
                horizontal: AppTheme.spacing24,
              ).copyWith(bottom: 100),
              children: [
                // ── Favorite Bus Lines ────────────────────────────
                const SizedBox(height: AppTheme.spacing32),
                _buildSectionLabel(
                  context,
                  'FAVORITE BUS LINES',
                  trailing: Text(
                    '${favoriteRoutes.length} active',
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                if (favoriteRoutes.isEmpty)
                  _buildEmptyHint(context, 'No favorite bus lines yet')
                else
                  serviceDescAsync.when(
                    data: (descriptions) =>
                        _buildRouteCards(favoriteRoutes, descriptions),
                    loading: () => _buildShimmerPlaceholder(),
                    error: (_, _) => _buildRouteCards(favoriteRoutes, []),
                  ),

                // ── Saved Stops ───────────────────────────────────
                const SizedBox(height: 40),
                _buildSectionLabel(
                  context,
                  'SAVED STOPS',
                  trailing: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        // Toggle edit mode (could be expanded later)
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacing4,
                          vertical: AppTheme.spacing4,
                        ),
                        child: Text(
                          'Edit List',
                          style: textTheme.labelSmall?.copyWith(
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spacing16),
                ...favoriteStops.map(
                  (stopName) => Padding(
                    key: ValueKey('stop_$stopName'),
                    padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
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
                _buildSectionLabel(context, 'RECENT ACTIVITY'),
                const SizedBox(height: AppTheme.spacing16),
                _buildRecentActivityCard(context),
                const SizedBox(height: AppTheme.spacing32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spacing24,
            vertical: AppTheme.spacing16,
          ),
          child: Row(
            children: [
              const Icon(Icons.star, color: AppTheme.primary, size: 28),
              const SizedBox(width: AppTheme.spacing12),
              Text(
                'Favorites',
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              // Add button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.go('/search');
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.borderDark),
                    ),
                    child: const Icon(
                      Icons.add,
                      color: AppTheme.primary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section label ─────────────────────────────────────────────────

  Widget _buildSectionLabel(
    BuildContext context,
    String title, {
    Widget? trailing,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Text(
          title,
          style: textTheme.labelSmall?.copyWith(
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
          key: ValueKey('route_$code'),
          padding: EdgeInsets.only(
            bottom: code != routes.last ? AppTheme.spacing12 : 0,
          ),
          child: FavoriteRouteCard(routeCode: code, description: desc),
        );
      }).toList(),
    );
  }

  // ── Empty state hint ──────────────────────────────────────────────

  // ── Shimmer loading placeholder ───────────────────────────────────

  Widget _buildShimmerPlaceholder() {
    return Shimmer.fromColors(
      baseColor: AppTheme.surfaceVariant,
      highlightColor: AppTheme.neutralDark,
      child: Column(
        children: List.generate(
          2,
          (i) => Padding(
            padding: EdgeInsets.only(bottom: i < 1 ? AppTheme.spacing12 : 0),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Empty state hint ──────────────────────────────────────────────

  Widget _buildEmptyHint(BuildContext context, String text) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.borderDark),
      ),
      child: Center(
        child: Text(
          text,
          style: textTheme.bodySmall?.copyWith(color: AppTheme.textMuted),
        ),
      ),
    );
  }

  // ── Add destination card ──────────────────────────────────────────

  Widget _buildAddDestinationCard(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        onTap: () {
          HapticFeedback.selectionClick();
          context.go('/search');
        },
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle, color: AppTheme.textMuted, size: 20),
              const SizedBox(width: AppTheme.spacing8),
              Text(
                'Add new destination',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent activity card ──────────────────────────────────────────

  Widget _buildRecentActivityCard(BuildContext context) {
    final recentTrips = ref.watch(favoritesRepositoryProvider).getRecentTrips();

    if (recentTrips.isEmpty) {
      return _buildActivityTile(
        context,
        from: 'UTown',
        to: 'Science',
        subtitle: '2 hours ago • Bus D1',
      );
    }

    final trip = recentTrips.first;
    return _buildActivityTile(
      context,
      from: trip['from'] ?? '',
      to: trip['to'] ?? '',
      subtitle: trip['time'] ?? 'Recently',
    );
  }

  Widget _buildActivityTile(
    BuildContext context, {
    required String from,
    required String to,
    required String subtitle,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: 0.6,
      child: ColorFiltered(
        colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.saturation),
        child: Container(
          padding: const EdgeInsets.all(AppTheme.spacing16),
          decoration: BoxDecoration(
            color: AppTheme.surfaceVariant.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: AppTheme.borderDark),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.history,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppTheme.spacing16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        style: textTheme.bodySmall?.copyWith(
                          color: AppTheme.textPrimary,
                        ),
                        children: [
                          const TextSpan(text: 'Traveled from '),
                          TextSpan(
                            text: from,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const TextSpan(text: ' to '),
                          TextSpan(
                            text: to,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.spacing4),
                    Text(
                      subtitle,
                      style: textTheme.labelSmall?.copyWith(
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
