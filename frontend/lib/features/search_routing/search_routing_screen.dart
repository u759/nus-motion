import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import 'package:frontend/app/theme.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/data/models/nearby_stop_result.dart';
import 'package:frontend/data/models/route_plan_result.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/search_routing/widgets/route_card.dart';
import 'package:frontend/features/search_routing/widgets/suggestion_tile.dart';

class SearchRoutingScreen extends ConsumerStatefulWidget {
  const SearchRoutingScreen({super.key});

  @override
  ConsumerState<SearchRoutingScreen> createState() =>
      _SearchRoutingScreenState();
}

class _SearchRoutingScreenState extends ConsumerState<SearchRoutingScreen> {
  final _toController = TextEditingController();
  final _fromController = TextEditingController();
  final _toFocus = FocusNode();
  final _fromFocus = FocusNode();
  int _tabIndex = 0; // 0=Suggested, 1=Nearby, 2=Recent

  String _fromValue = 'Current Location';
  bool _isEditingFrom = false;
  bool _hasSubmitted = false;
  String? _resolvedOrigin;

  @override
  void initState() {
    super.initState();
    _toFocus.requestFocus();
    _toController.addListener(() => setState(() {}));
    _fromController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _toController.dispose();
    _fromController.dispose();
    _toFocus.dispose();
    _fromFocus.dispose();
    super.dispose();
  }

  void _submitRoute() async {
    final dest = _toController.text.trim();
    if (dest.isEmpty) return;

    String origin = _fromValue;

    // If origin is "Current Location", resolve to nearest stop
    if (origin == 'Current Location') {
      final posAsync = ref.read(positionStreamProvider);
      final pos = posAsync.valueOrNull;
      final lat = pos?.latitude ?? 1.2966;
      final lng = pos?.longitude ?? 103.7764;

      try {
        final stops = await ref
            .read(transitServiceProvider)
            .getNearbyStops(lat, lng);
        if (stops.isNotEmpty) {
          origin = stops.first.stopName;
        }
      } catch (_) {
        // Fall through with unresolved origin
      }
    }

    ref.read(recentSearchesProvider.notifier).add(dest);
    setState(() {
      _resolvedOrigin = origin;
      _hasSubmitted = true;
      _isEditingFrom = false;
    });
  }

  void _selectSuggestion(String name) {
    _toController.text = name;
    _submitRoute();
  }

  void _selectFromSuggestion(String name) {
    setState(() {
      _fromValue = name;
      _fromController.clear();
      _isEditingFrom = false;
    });
    _toFocus.requestFocus();
  }

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppTheme.durationMedium,
                switchInCurve: AppTheme.curve,
                switchOutCurve: AppTheme.curve,
                child: _isEditingFrom
                    ? _buildFromSuggestions()
                    : _hasSubmitted
                    ? _buildRouteResults()
                    : _buildSearchContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticky header: back/title/settings + inputs + tabs ─────────
  Widget _buildHeader() {
    return Container(
      color: AppTheme.backgroundDark.withValues(alpha: 0.95),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Title bar
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing12,
              AppTheme.spacing16,
              AppTheme.spacing4,
            ),
            child: Row(
              children: [
                _circleButton(Icons.arrow_back, () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/');
                  }
                }),
                const SizedBox(width: AppTheme.spacing8),
                Expanded(
                  child: Text(
                    'Routing',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                Icon(
                  Icons.settings_input_component,
                  color: AppTheme.primary,
                  size: 24,
                ),
              ],
            ),
          ),

          // Input fields
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              0,
            ),
            child: Column(
              children: [
                // From (editable)
                InkWell(
                  onTap: _isEditingFrom
                      ? null
                      : () {
                          setState(() {
                            _isEditingFrom = true;
                            _hasSubmitted = false;
                          });
                          _fromFocus.requestFocus();
                        },
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                  child: _inputField(
                    icon: Icons.radio_button_checked,
                    iconColor: AppTheme.primary.withValues(alpha: 0.6),
                    active: _isEditingFrom,
                    child: _isEditingFrom
                        ? TextField(
                            controller: _fromController,
                            focusNode: _fromFocus,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: AppTheme.textPrimary),
                            decoration: InputDecoration(
                              hintText: 'Search origin…',
                              hintStyle: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppTheme.textMuted),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onSubmitted: (_) {
                              final text = _fromController.text.trim();
                              if (text.isNotEmpty) {
                                _selectFromSuggestion(text);
                              } else {
                                setState(() => _isEditingFrom = false);
                              }
                            },
                          )
                        : Text(
                            _fromValue,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: _fromValue == 'Current Location'
                                      ? AppTheme.textSecondary
                                      : AppTheme.textPrimary,
                                ),
                          ),
                    trailing: _isEditingFrom
                        ? InkWell(
                            onTap: () {
                              _fromController.clear();
                              setState(() {
                                _fromValue = 'Current Location';
                                _isEditingFrom = false;
                              });
                            },
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                            child: const Icon(
                              Icons.cancel,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                          )
                        : _fromValue != 'Current Location'
                        ? InkWell(
                            onTap: () {
                              setState(() {
                                _fromValue = 'Current Location';
                              });
                            },
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusFull,
                            ),
                            child: const Icon(
                              Icons.my_location,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing12),
                // To (editable)
                _inputField(
                  icon: Icons.location_on,
                  iconColor: AppTheme.primary,
                  active: true,
                  child: TextField(
                    controller: _toController,
                    focusNode: _toFocus,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search destination…',
                      hintStyle: Theme.of(context).textTheme.bodyMedium
                          ?.copyWith(color: AppTheme.textMuted),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onSubmitted: (_) => _submitRoute(),
                  ),
                  trailing: _toController.text.isNotEmpty
                      ? InkWell(
                          onTap: () {
                            _toController.clear();
                            setState(() => _hasSubmitted = false);
                          },
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusFull,
                          ),
                          child: const Icon(
                            Icons.cancel,
                            color: AppTheme.textMuted,
                            size: 18,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),

          // Tabs
          const SizedBox(height: AppTheme.spacing12),
          _buildTabs(),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(icon, color: AppTheme.textPrimary, size: 24),
      ),
    );
  }

  Widget _inputField({
    required IconData icon,
    required Color iconColor,
    required Widget child,
    required bool active,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.neutralDark,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: active
            ? Border.all(
                color: AppTheme.primary.withValues(alpha: 0.5),
                width: 1,
              )
            : null,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing12,
        vertical: 10,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 10),
          Expanded(child: child),
          if (trailing != null) ...[
            const SizedBox(width: AppTheme.spacing8),
            trailing,
          ],
        ],
      ),
    );
  }

  // ── Tabs ────────────────────────────────────────────────────────
  Widget _buildTabs() {
    const labels = ['Suggested', 'Nearby', 'Recent'];
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.borderDark)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing16),
      child: Row(
        children: List.generate(labels.length, (i) {
          final active = i == _tabIndex;
          return InkWell(
            onTap: () {
              if (_tabIndex != i) {
                HapticFeedback.selectionClick();
              }
              setState(() {
                _tabIndex = i;
                _hasSubmitted = false;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: AppTheme.spacing24),
              padding: const EdgeInsets.only(
                top: AppTheme.spacing8,
                bottom: AppTheme.spacing12,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: active ? AppTheme.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
              child: AnimatedDefaultTextStyle(
                duration: AppTheme.durationFast,
                curve: AppTheme.curve,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: active ? AppTheme.primary : AppTheme.textMuted,
                ),
                child: Text(labels[i].toUpperCase()),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Search content (suggestions / nearby / recent) ──────────────
  Widget _buildSearchContent() {
    return AnimatedSwitcher(
      duration: AppTheme.durationMedium,
      switchInCurve: AppTheme.curve,
      switchOutCurve: AppTheme.curve,
      child: KeyedSubtree(
        key: ValueKey<int>(_tabIndex),
        child: switch (_tabIndex) {
          0 => _buildSuggestedTab(),
          1 => _buildNearbyTab(),
          2 => _buildRecentTab(),
          _ => const SizedBox.shrink(),
        },
      ),
    );
  }

  // ── Suggested tab ───────────────────────────────────────────────
  Widget _buildSuggestedTab() {
    final query = _toController.text.trim().toLowerCase();
    final stopsAsync = ref.watch(stopsProvider);
    final buildingsAsync = ref.watch(buildingsProvider);
    final recents = ref.watch(recentSearchesProvider);

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Autocomplete panel
        if (query.isNotEmpty)
          _buildAutocompletePanel(query, stopsAsync, buildingsAsync, recents),
      ],
    );
  }

  Widget _buildAutocompletePanel(
    String query,
    AsyncValue<List<BusStop>> stopsAsync,
    AsyncValue<List<Building>> buildingsAsync,
    List<String> recents,
  ) {
    // Combine matching results
    final List<_SuggestionItem> items = [];

    // Recent matches first
    for (final r in recents) {
      if (r.toLowerCase().contains(query)) {
        items.add(_SuggestionItem(r, null, SuggestionType.recent));
      }
    }

    // Bus stop matches
    stopsAsync.whenData((stops) {
      for (final s in stops) {
        if (s.longName.toLowerCase().contains(query) ||
            s.shortName.toLowerCase().contains(query) ||
            s.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(
              s.longName.isNotEmpty ? s.longName : s.name,
              s.shortName.isNotEmpty ? s.shortName : null,
              SuggestionType.stop,
            ),
          );
        }
      }
    });

    // Building matches
    buildingsAsync.whenData((buildings) {
      for (final b in buildings) {
        if (b.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(b.name, b.address, SuggestionType.building),
          );
        }
      }
    });

    if (items.isEmpty) return const SizedBox.shrink();

    // Limit visible suggestions
    final visible = items.take(8).toList();

    return Container(
      color: AppTheme.primary.withValues(alpha: 0.05),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spacing16,
        AppTheme.spacing8,
        AppTheme.spacing16,
        AppTheme.spacing4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUGGESTIONS',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: AppTheme.spacing8),
          for (final item in visible)
            SuggestionTile(
              key: ValueKey<String>('suggestion_${item.name}'),
              name: item.name,
              subtitle: item.subtitle,
              type: item.type,
              onTap: () => _selectSuggestion(item.name),
            ),
        ],
      ),
    );
  }

  // ── From-field suggestions ──────────────────────────────────────
  Widget _buildFromSuggestions() {
    final query = _fromController.text.trim().toLowerCase();
    final stopsAsync = ref.watch(stopsProvider);
    final buildingsAsync = ref.watch(buildingsProvider);

    final List<_SuggestionItem> items = [];

    // Always show "Current Location" at top
    if (query.isEmpty || 'current location'.contains(query)) {
      items.add(
        const _SuggestionItem(
          'Current Location',
          'Use device GPS',
          SuggestionType.recent, // reuse icon style
        ),
      );
    }

    // Bus stop matches
    stopsAsync.whenData((stops) {
      for (final s in stops) {
        if (query.isEmpty ||
            s.longName.toLowerCase().contains(query) ||
            s.shortName.toLowerCase().contains(query) ||
            s.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(
              s.longName.isNotEmpty ? s.longName : s.name,
              s.shortName.isNotEmpty ? s.shortName : null,
              SuggestionType.stop,
            ),
          );
        }
      }
    });

    // Building matches
    buildingsAsync.whenData((buildings) {
      for (final b in buildings) {
        if (query.isEmpty || b.name.toLowerCase().contains(query)) {
          items.add(
            _SuggestionItem(b.name, b.address, SuggestionType.building),
          );
        }
      }
    });

    final visible = items.take(10).toList();

    return KeyedSubtree(
      key: const ValueKey('from_suggestions'),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            color: AppTheme.primary.withValues(alpha: 0.05),
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spacing16,
              AppTheme.spacing8,
              AppTheme.spacing16,
              AppTheme.spacing4,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SELECT ORIGIN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primary,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing8),
                for (final item in visible)
                  SuggestionTile(
                    key: ValueKey<String>('from_suggestion_${item.name}'),
                    name: item.name,
                    subtitle: item.subtitle,
                    type: item.type,
                    onTap: () => _selectFromSuggestion(item.name),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nearby tab ──────────────────────────────────────────────────
  Widget _buildNearbyTab() {
    // Use live device location, fallback to NUS campus center
    final posAsync = ref.watch(positionStreamProvider);
    final pos = posAsync.valueOrNull;
    final lat = pos?.latitude ?? 1.2966;
    final lng = pos?.longitude ?? 103.7764;
    final nearbyAsync = ref.watch(nearbyStopsProvider((lat: lat, lng: lng)));

    return nearbyAsync.when(
      loading: () => _buildShimmerList(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Text(
            'Failed to load nearby stops',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      ),
      data: (stops) => _buildNearbyStopsList(stops),
    );
  }

  Widget _buildNearbyStopsList(List<NearbyStopResult> stops) {
    if (stops.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Text(
            'No nearby stops found',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      itemCount: stops.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
            child: Text(
              'NEARBY STOPS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.textMuted,
                letterSpacing: 2.0,
              ),
            ),
          );
        }
        final stop = stops[index - 1];
        return Padding(
          key: ValueKey<String>('nearby_${stop.stopName}'),
          padding: const EdgeInsets.only(bottom: AppTheme.spacing8),
          child: _NearbyStopCard(
            stop: stop,
            onTap: () => _selectSuggestion(stop.stopName),
          ),
        );
      },
    );
  }

  // ── Recent tab ──────────────────────────────────────────────────
  Widget _buildRecentTab() {
    final recents = ref.watch(recentSearchesProvider);
    if (recents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Text(
            'No recent searches',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textMuted),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacing16,
        vertical: AppTheme.spacing8,
      ),
      children: [
        for (final r in recents)
          SuggestionTile(
            key: ValueKey<String>('recent_$r'),
            name: r,
            type: SuggestionType.recent,
            onTap: () => _selectSuggestion(r),
          ),
      ],
    );
  }

  // ── Route results ───────────────────────────────────────────────
  Widget _buildRouteResults() {
    final dest = _toController.text.trim();
    final routeAsync = ref.watch(
      routeProvider((from: _resolvedOrigin ?? _fromValue, to: dest)),
    );

    return routeAsync.when(
      loading: () => _buildShimmerList(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spacing32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: AppTheme.textMuted,
                size: 40,
              ),
              const SizedBox(height: AppTheme.spacing12),
              Text(
                'Could not find a route',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppTheme.spacing8),
              TextButton(
                onPressed: () => setState(() => _hasSubmitted = false),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (result) => _buildRouteResultsList(result),
    );
  }

  Widget _buildRouteResultsList(RoutePlanResult result) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
          child: Text(
            'FASTEST ROUTES',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppTheme.textMuted,
              letterSpacing: 2.0,
            ),
          ),
        ),

        // Primary route card
        RouteCard(key: const ValueKey('route_primary'), result: result),

        const SizedBox(height: AppTheme.spacing12),

        // Secondary card (dimmed) – reuse same result for visual match
        RouteCard(
          key: const ValueKey('route_secondary'),
          result: result,
          dimmed: true,
        ),

        const SizedBox(height: AppTheme.spacing24),

        // Nearby stops section at bottom
        _buildNearbyStopsFooter(),
      ],
    );
  }

  Widget _buildNearbyStopsFooter() {
    final posAsync = ref.watch(positionStreamProvider);
    final pos = posAsync.valueOrNull;
    final lat = pos?.latitude ?? 1.2966;
    final lng = pos?.longitude ?? 103.7764;
    final nearbyAsync = ref.watch(nearbyStopsProvider((lat: lat, lng: lng)));

    return nearbyAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (stops) {
        if (stops.isEmpty) return const SizedBox.shrink();
        final visible = stops.take(3).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing12),
              child: Text(
                'NEARBY STOPS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textMuted,
                  letterSpacing: 2.0,
                ),
              ),
            ),
            for (final stop in visible) ...[
              _NearbyStopCard(
                key: ValueKey<String>('footer_nearby_${stop.stopName}'),
                stop: stop,
                onTap: () => _selectSuggestion(stop.stopName),
              ),
              const SizedBox(height: AppTheme.spacing8),
            ],
          ],
        );
      },
    );
  }

  // ── Shimmer loading state ───────────────────────────────────────
  Widget _buildShimmerList() {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spacing16),
      child: Shimmer.fromColors(
        baseColor: AppTheme.surfaceVariant,
        highlightColor: AppTheme.neutralDark,
        child: Column(
          children: List.generate(
            3,
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.spacing16),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper models ─────────────────────────────────────────────────────

class _SuggestionItem {
  const _SuggestionItem(this.name, this.subtitle, this.type);
  final String name;
  final String? subtitle;
  final SuggestionType type;
}

// ── Nearby stop card ──────────────────────────────────────────────────

class _NearbyStopCard extends StatelessWidget {
  const _NearbyStopCard({super.key, required this.stop, this.onTap});
  final NearbyStopResult stop;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Ink(
        padding: const EdgeInsets.all(AppTheme.spacing12),
        decoration: BoxDecoration(
          color: AppTheme.neutralDark.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.borderDark),
        ),
        child: Row(
          children: [
            const Icon(Icons.directions_bus, color: AppTheme.primary, size: 20),
            const SizedBox(width: AppTheme.spacing12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stop.stopDisplayName,
                    style: textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${stop.distanceMeters.round()}m away',
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
    );
  }
}
