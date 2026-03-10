import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/weather_widget.dart';
import 'package:frontend/data/models/building.dart';
import 'package:frontend/data/models/bus_stop.dart';
import 'package:frontend/state/providers.dart';
import 'package:frontend/features/map_discovery/models/navigation_state.dart';
import 'package:geolocator/geolocator.dart';

/// Search result item representing either a building or bus stop.
class _SearchResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final bool isStop;

  const _SearchResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.isStop,
  });
}

/// Inline search dropdown that appears below the search bar.
///
/// Shows closest buildings/stops when empty, filtered results when typing.
/// On selection, calls [NavigationStateNotifier.selectDestination].
class SearchDropdown extends ConsumerStatefulWidget {
  final Position? userPosition;
  final VoidCallback? onDestinationSelected;

  const SearchDropdown({
    super.key,
    this.userPosition,
    this.onDestinationSelected,
  });

  @override
  ConsumerState<SearchDropdown> createState() => _SearchDropdownState();
}

class _SearchDropdownState extends ConsumerState<SearchDropdown>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();

  OverlayEntry? _overlayEntry;
  bool _isDropdownVisible = false;
  String _query = '';

  // Animation for dropdown appearance
  late final AnimationController _dropdownAnimController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);

    // Initialize dropdown animation
    _dropdownAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _dropdownAnimController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _dropdownAnimController,
            curve: Curves.easeOut,
          ),
        );
  }

  @override
  void dispose() {
    _hideDropdown();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    _dropdownAnimController.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      // Delay to allow tap on results
      Future.delayed(const Duration(milliseconds: 150), () {
        if (!_focusNode.hasFocus && mounted) {
          _hideDropdown();
        }
      });
    }
  }

  void _showDropdown() {
    if (_isDropdownVisible) return;
    _isDropdownVisible = true;
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
    _dropdownAnimController.forward(from: 0);
  }

  void _hideDropdown() {
    if (!_isDropdownVisible) return;
    _isDropdownVisible = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _updateDropdown() {
    _overlayEntry?.markNeedsBuild();
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 8),
          child: Material(
            elevation: 0,
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: _buildDropdownContent(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownContent() {
    final colors = context.nusColors;
    return TapRegion(
      onTapOutside: (_) {
        _focusNode.unfocus();
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 320),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          // Use Consumer to properly respond to provider changes in overlay
          child: Consumer(
            builder: (context, ref, _) => _buildFilteredResults(context, ref),
          ),
        ),
      ),
    );
  }

  /// Minimum characters required before searching.
  static const _minQueryLength = 3;

  Widget _buildFilteredResults(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;

    // Show placeholder for short queries — don't trigger loading state
    if (_query.length < _minQueryLength) {
      return _buildMinCharsHint(colors);
    }

    final stopsAsync = ref.watch(stopsProvider);
    final buildingsAsync = ref.watch(buildingsProvider);

    return stopsAsync.when(
      data: (stops) => buildingsAsync.when(
        data: (buildings) {
          final results = _filterResults(stops, buildings, _query);
          if (results.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 20,
                    color: colors.textMuted.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'No results found',
                    style: TextStyle(color: colors.textMuted, fontSize: 14),
                  ),
                ],
              ),
            );
          }
          return _buildResultsList(context, results);
        },
        loading: () => _buildLoadingState(colors),
        error: (_, __) => _buildErrorState(colors),
      ),
      loading: () => _buildLoadingState(colors),
      error: (_, __) => _buildErrorState(colors),
    );
  }

  List<_SearchResult> _filterResults(
    List<BusStop> stops,
    List<Building> buildings,
    String query,
  ) {
    final q = query.toLowerCase();
    final results = <_SearchResult>[];
    final userPos = widget.userPosition;

    // Filter stops
    for (final stop in stops) {
      if (stop.longName.toLowerCase().contains(q) ||
          stop.shortName.toLowerCase().contains(q) ||
          stop.name.toLowerCase().contains(q) ||
          stop.caption.toLowerCase().contains(q)) {
        final dist = userPos != null
            ? _haversineDistance(
                userPos.latitude,
                userPos.longitude,
                stop.latitude,
                stop.longitude,
              )
            : 0.0;
        results.add(
          _SearchResult(
            name: stop.name,
            displayName: stop.longName.isNotEmpty ? stop.longName : stop.name,
            latitude: stop.latitude,
            longitude: stop.longitude,
            distanceMeters: dist,
            isStop: true,
          ),
        );
      }
    }

    // Filter buildings
    for (final building in buildings) {
      if (building.name.toLowerCase().contains(q)) {
        final dist = userPos != null
            ? _haversineDistance(
                userPos.latitude,
                userPos.longitude,
                building.latitude,
                building.longitude,
              )
            : 0.0;
        results.add(
          _SearchResult(
            name: building.name,
            displayName: building.name,
            latitude: building.latitude,
            longitude: building.longitude,
            distanceMeters: dist,
            isStop: false,
          ),
        );
      }
    }

    return results.take(8).toList();
  }

  Widget _buildResultsList(BuildContext context, List<_SearchResult> results) {
    final colors = context.nusColors;
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: results.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, indent: 52, color: colors.borderLight),
      itemBuilder: (context, index) {
        final result = results[index];
        return FadeSlideIn(
          key: ValueKey('search_fade_${result.name}'),
          delay: Duration(milliseconds: 30 * index.clamp(0, 8)),
          child: _SearchResultTile(
            result: result,
            onTap: () => _selectResult(result),
          ),
        );
      },
    );
  }

  Widget _buildLoadingState(NusColorsData colors) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: colors.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMinCharsHint(NusColorsData colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            Icons.keyboard,
            size: 20,
            color: colors.textMuted.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Text(
            'Type $_minQueryLength+ characters to search',
            style: TextStyle(color: colors.textMuted, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(NusColorsData colors) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 20, color: colors.error),
          const SizedBox(width: 8),
          Text(
            'Failed to load locations',
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _selectResult(_SearchResult result) {
    // Create a Building object for the navigation state
    final building = Building(
      elementId: result.name,
      name: result.displayName,
      address: '',
      postal: '',
      latitude: result.latitude,
      longitude: result.longitude,
    );

    // Update navigation state
    ref.read(navigationStateProvider.notifier).selectDestination(building);

    // Clear and close
    _controller.clear();
    setState(() => _query = '');
    _focusNode.unfocus();
    _hideDropdown();

    // Notify parent
    widget.onDestinationSelected?.call();
  }

  static double _haversineDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const r = 6371e3;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Icon(
                      Icons.search,
                      color: colors.textSecondary,
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      decoration: InputDecoration(
                        filled: false,
                        hintText: 'Where are you heading?',
                        hintStyle: TextStyle(
                          color: colors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                      ),
                      style: TextStyle(fontSize: 15, color: colors.textPrimary),
                      onChanged: (value) {
                        setState(() => _query = value);
                        if (value.isNotEmpty && !_isDropdownVisible) {
                          _showDropdown();
                        } else if (value.isEmpty && _isDropdownVisible) {
                          _hideDropdown();
                        } else {
                          _updateDropdown();
                        }
                      },
                    ),
                  ),
                  if (_query.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _controller.clear();
                        setState(() => _query = '');
                        _hideDropdown();
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Icon(
                          Icons.clear,
                          color: colors.textMuted,
                          size: 20,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 12),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          const WeatherWidget(),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()}m';
    }
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: result.isStop ? colors.successBg : colors.infoBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                result.isStop ? Icons.directions_bus : Icons.location_on,
                color: result.isStop ? colors.success : colors.primary,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                result.displayName,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (result.distanceMeters > 0)
              Text(
                _formatDistance(result.distanceMeters),
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
