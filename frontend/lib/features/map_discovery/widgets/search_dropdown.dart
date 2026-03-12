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

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

/// A resolved location that can sit in either the origin or destination slot.
/// [isCurrentLocation] means "use GPS" — no Building attached.
class _FieldValue {
  final Building? building;
  final bool isCurrentLocation;

  const _FieldValue.currentLocation()
    : building = null,
      isCurrentLocation = true;

  const _FieldValue.place(this.building) : isCurrentLocation = false;

  /// Display label for the field.
  String get label =>
      isCurrentLocation ? 'Current Location' : (building?.name ?? '');

  bool get isEmpty => !isCurrentLocation && building == null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _FieldValue &&
          isCurrentLocation == other.isCurrentLocation &&
          building?.name == other.building?.name;

  @override
  int get hashCode => Object.hash(isCurrentLocation, building?.name);
}

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

  Building toBuilding() => Building(
    elementId: name,
    name: displayName,
    address: '',
    postal: '',
    latitude: latitude,
    longitude: longitude,
  );
}

/// Which field is currently being edited in expanded mode.
enum _ActiveField { none, origin, destination }

// ---------------------------------------------------------------------------
// Widget
// ---------------------------------------------------------------------------

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
  // ---- Controllers & focus ----
  final _originController = TextEditingController();
  final _destController = TextEditingController();
  final _originFocus = FocusNode();
  final _destFocus = FocusNode();
  final _layerLink = LayerLink();

  // ---- State ----
  bool _expanded = false;
  _ActiveField _activeField = _ActiveField.none;
  String _query = '';

  /// What is currently in the origin slot.
  _FieldValue _originValue = const _FieldValue.currentLocation();

  /// What is currently in the destination slot (empty until user picks).
  _FieldValue _destValue = const _FieldValue.place(null);

  // ---- Overlay ----
  OverlayEntry? _overlayEntry;
  bool _dropdownVisible = false;

  // ---- Animation ----
  late final AnimationController _dropdownAnim;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Track swap rotation for visual feedback
  int _swapCount = 0;

  static const _minQueryLength = 3;

  // -------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _originFocus.addListener(_onOriginFocusChange);
    _destFocus.addListener(_onDestFocusChange);

    _dropdownAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnim = CurvedAnimation(parent: _dropdownAnim, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _dropdownAnim, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _hideDropdown();
    _originFocus.removeListener(_onOriginFocusChange);
    _destFocus.removeListener(_onDestFocusChange);
    _originFocus.dispose();
    _destFocus.dispose();
    _originController.dispose();
    _destController.dispose();
    _dropdownAnim.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------
  // Focus handling
  // -------------------------------------------------------------------

  void _onOriginFocusChange() {
    if (_originFocus.hasFocus) {
      setState(() => _activeField = _ActiveField.origin);
      _query = _originController.text;
      if (_query.length >= _minQueryLength) _showDropdown();
    } else {
      _scheduleBlur();
    }
  }

  void _onDestFocusChange() {
    if (_destFocus.hasFocus) {
      setState(() => _activeField = _ActiveField.destination);
      _query = _destController.text;
      if (_query.length >= _minQueryLength) _showDropdown();
    } else {
      _scheduleBlur();
    }
  }

  void _scheduleBlur() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (!mounted) return;
      if (!_originFocus.hasFocus && !_destFocus.hasFocus) {
        _hideDropdown();
        _collapse();
      }
    });
  }

  // -------------------------------------------------------------------
  // Expand / collapse
  // -------------------------------------------------------------------

  void _expand() {
    if (_expanded) return;
    setState(() => _expanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _destFocus.requestFocus();
    });
  }

  void _collapse() {
    if (!_expanded) return;
    setState(() {
      _expanded = false;
      _activeField = _ActiveField.none;
    });
    _originController.clear();
    _destController.clear();
    _query = '';
  }

  /// Force-close: unfocus, hide dropdown, collapse. Used by X button & back gesture.
  void _close() {
    _originFocus.unfocus();
    _destFocus.unfocus();
    _hideDropdown();
    _collapse();
  }

  // -------------------------------------------------------------------
  // Overlay management
  // -------------------------------------------------------------------

  void _showDropdown() {
    if (_dropdownVisible) {
      _overlayEntry?.markNeedsBuild();
      return;
    }
    _dropdownVisible = true;
    _overlayEntry = _createOverlay();
    Overlay.of(context).insert(_overlayEntry!);
    _dropdownAnim.forward(from: 0);
  }

  void _hideDropdown() {
    if (!_dropdownVisible) return;
    _dropdownVisible = false;
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlay() {
    final box = context.findRenderObject() as RenderBox;
    final size = box.size;
    return OverlayEntry(
      builder: (_) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 8),
          child: Material(
            color: Colors.transparent,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: _DropdownBody(
                  query: _query,
                  minQueryLength: _minQueryLength,
                  userPosition: widget.userPosition,
                  onSelect: _onResultSelected,
                  onTapOutside: () {
                    _originFocus.unfocus();
                    _destFocus.unfocus();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------
  // Text field change
  // -------------------------------------------------------------------

  void _onFieldChanged(String value, _ActiveField field) {
    setState(() {
      _query = value;
      _activeField = field;
    });
    if (value.length >= _minQueryLength) {
      _showDropdown();
    } else if (_dropdownVisible) {
      _hideDropdown();
    } else {
      _overlayEntry?.markNeedsBuild();
    }
  }

  // -------------------------------------------------------------------
  // Selection
  // -------------------------------------------------------------------

  void _onResultSelected(_SearchResult result) {
    if (_activeField == _ActiveField.origin) {
      _pickOrigin(result);
    } else {
      _pickDestination(result);
    }
  }

  void _pickOrigin(_SearchResult result) {
    final building = result.toBuilding();
    setState(() {
      _originValue = _FieldValue.place(building);
    });
    _originController.clear();
    _hideDropdown();
    ref.read(navigationStateProvider.notifier).setOrigin(building);
    _destFocus.requestFocus();
  }

  void _pickDestination(_SearchResult result) {
    final building = result.toBuilding();
    setState(() {
      _destValue = _FieldValue.place(building);
      _query = '';
    });
    _destController.clear();
    _originFocus.unfocus();
    _destFocus.unfocus();
    _hideDropdown();
    _collapse();
    ref.read(navigationStateProvider.notifier).selectDestination(building);
    widget.onDestinationSelected?.call();
  }

  void _resetOriginToGps() {
    setState(() => _originValue = const _FieldValue.currentLocation());
    _originController.clear();
    ref.read(navigationStateProvider.notifier).setOrigin(null);
  }

  // -------------------------------------------------------------------
  // ★ SWAP — the heart of the fix
  // -------------------------------------------------------------------
  //
  // Google Maps behaviour:
  //   Origin = "Current Location", Dest = empty  →  Origin becomes empty
  //     (editable), Dest becomes "Current Location" label.
  //   Origin = place A, Dest = place B  →  Origin = B, Dest = A (selects A
  //     as destination, triggering route search).
  //   Origin = "Current Location", Dest = typed text "COM"  →  Origin shows
  //     "COM" text (still searching), Dest shows "Current Location".
  //
  // The key insight: swap is purely a field-value exchange. Afterwards,
  // if the new destination is a resolved Building, commit it to nav state.
  // If it's "Current Location" or raw text, just show it in the field.

  void _swap() {
    final oldOrigin = _originValue;
    final oldOriginText = _originController.text;
    final oldDest = _destValue;
    final oldDestText = _destController.text;

    setState(() {
      _swapCount++;

      // --- New origin = whatever was in dest ---
      if (!oldDest.isEmpty) {
        // Dest had a resolved place → move it to origin
        _originValue = oldDest;
        _originController.clear();
      } else if (oldDestText.isNotEmpty) {
        // Dest had unresolved text → move text to origin field
        _originValue = const _FieldValue.place(null); // empty, editing
        _originController.text = oldDestText;
      } else {
        // Dest was completely empty → origin becomes empty (editable)
        _originValue = const _FieldValue.place(null);
        _originController.clear();
      }

      // --- New dest = whatever was in origin ---
      if (oldOrigin.isCurrentLocation) {
        // "Current Location" can't be typed — just blank the field,
        // and we'll show it as the "Your location" chip in dest.
        _destValue = const _FieldValue.currentLocation();
        _destController.clear();
      } else if (!oldOrigin.isEmpty) {
        // Origin had a resolved place → it becomes the new destination
        _destValue = oldOrigin;
        _destController.clear();
      } else if (oldOriginText.isNotEmpty) {
        // Origin had unresolved text → move to dest field
        _destValue = const _FieldValue.place(null);
        _destController.text = oldOriginText;
      } else {
        _destValue = const _FieldValue.place(null);
        _destController.clear();
      }

      _query = '';
    });

    // --- Sync to NavigationState ---
    final nav = ref.read(navigationStateProvider.notifier);

    // Origin → nav
    if (_originValue.isCurrentLocation) {
      nav.setOrigin(null);
    } else if (_originValue.building != null) {
      nav.setOrigin(_originValue.building);
    } else {
      nav.setOrigin(null);
    }

    // Dest → nav: if the new dest is a resolved Building, commit it
    // (this triggers route suggestions). Otherwise clear destination.
    if (_destValue.building != null) {
      nav.selectDestination(_destValue.building!);
      _destFocus.unfocus();
      _originFocus.unfocus();
      _hideDropdown();
      _collapse();
      widget.onDestinationSelected?.call();
    } else {
      nav.clearDestination();
      // Keep expanded so user can finish typing
      _hideDropdown();
    }
  }

  // -------------------------------------------------------------------
  // Origin field: tap to edit
  // -------------------------------------------------------------------

  void _beginEditingOrigin() {
    // If there's a resolved origin, pre-fill its name for editing
    if (_originValue.building != null) {
      _originController.text = _originValue.building!.name;
      _originController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _originController.text.length,
      );
    }
    setState(() {
      _originValue = const _FieldValue.place(null); // clear resolved value
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _originFocus.requestFocus();
    });
  }

  // -------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;
    return PopScope(
      canPop: !_expanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: CompositedTransformTarget(
        link: _layerLink,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: _expanded ? _buildExpanded(colors) : _buildCollapsed(colors),
        ),
      ),
    );
  }

  // ---------- Collapsed ----------

  Widget _buildCollapsed(NusColorsData colors) {
    return Row(
      children: [
        Expanded(
          child: PressableScale(
            onTap: _expand,
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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      child: Text(
                        'Where are you heading?',
                        style: TextStyle(
                          color: colors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        const WeatherWidget(),
      ],
    );
  }

  // ---------- Expanded ----------

  Widget _buildExpanded(NusColorsData colors) {
    return Container(
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left: vertical dot connector
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: SizedBox(
              width: 14,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(colors.primary, 10),
                  for (int i = 0; i < 3; i++) ...[
                    const SizedBox(height: 4),
                    _dot(colors.textMuted.withValues(alpha: 0.4), 3),
                  ],
                  const SizedBox(height: 4),
                  _dot(colors.error, 10),
                ],
              ),
            ),
          ),
          // Middle: fields
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOriginRow(colors),
                Divider(
                  height: 1,
                  indent: 8,
                  endIndent: 8,
                  color: colors.borderLight,
                ),
                _buildDestRow(colors),
              ],
            ),
          ),
          // Right: close (top) + swap (bottom)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button — aligned with origin row
                PressableScale(
                  onTap: _close,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.close,
                      color: colors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                // Swap button — aligned with destination row
                PressableScale(
                  onTap: _swap,
                  child: AnimatedRotation(
                    turns: _swapCount * 0.5,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.swap_vert_rounded,
                        color: colors.textSecondary,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color, double size) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );

  // ---------- Origin row ----------

  Widget _buildOriginRow(NusColorsData colors) {
    // Case 1: resolved place — show read-only label with X button
    if (_originValue.building != null) {
      return _readOnlyField(
        colors: colors,
        label: _originValue.building!.name,
        icon: null,
        onTap: _beginEditingOrigin,
        onClear: _resetOriginToGps,
      );
    }

    // Case 2: "Current Location" — show styled label, tappable to edit
    if (_originValue.isCurrentLocation) {
      return _readOnlyField(
        colors: colors,
        label: 'Current Location',
        labelColor: colors.primary,
        icon: Icon(Icons.my_location, size: 16, color: colors.primary),
        onTap: _beginEditingOrigin,
        onClear: null, // already at GPS, nothing to clear
      );
    }

    // Case 3: empty / editing — show TextField
    return TextField(
      controller: _originController,
      focusNode: _originFocus,
      decoration: InputDecoration(
        filled: false,
        hintText: 'Search origin…',
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
        suffixIcon: _originController.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _originController.clear();
                  _resetOriginToGps();
                },
                child: Icon(Icons.close, size: 18, color: colors.textMuted),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
      style: TextStyle(fontSize: 14, color: colors.textPrimary),
      onChanged: (v) => _onFieldChanged(v, _ActiveField.origin),
    );
  }

  // ---------- Destination row ----------

  Widget _buildDestRow(NusColorsData colors) {
    // If dest is "Current Location" (from swap), show read-only label
    if (_destValue.isCurrentLocation) {
      return _readOnlyField(
        colors: colors,
        label: 'Current Location',
        labelColor: colors.primary,
        icon: Icon(Icons.my_location, size: 16, color: colors.primary),
        onTap: () {
          // Tapping clears it back to empty so user can type
          setState(() => _destValue = const _FieldValue.place(null));
          _destController.clear();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _destFocus.requestFocus();
          });
        },
        onClear: () {
          setState(() => _destValue = const _FieldValue.place(null));
          _destController.clear();
        },
      );
    }

    // If dest has a resolved building (from swap), show read-only label
    if (_destValue.building != null) {
      return _readOnlyField(
        colors: colors,
        label: _destValue.building!.name,
        onTap: () {
          _destController.text = _destValue.building!.name;
          _destController.selection = TextSelection(
            baseOffset: 0,
            extentOffset: _destController.text.length,
          );
          setState(() => _destValue = const _FieldValue.place(null));
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _destFocus.requestFocus();
          });
        },
        onClear: () {
          setState(() => _destValue = const _FieldValue.place(null));
          _destController.clear();
          _hideDropdown();
        },
      );
    }

    // Default: editable TextField
    return TextField(
      controller: _destController,
      focusNode: _destFocus,
      decoration: InputDecoration(
        filled: false,
        hintText: 'Where to?',
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 12,
        ),
        isDense: true,
        suffixIcon: _destController.text.isNotEmpty
            ? GestureDetector(
                onTap: () {
                  _destController.clear();
                  setState(() => _query = '');
                  _hideDropdown();
                },
                child: Icon(Icons.close, size: 18, color: colors.textMuted),
              )
            : null,
        suffixIconConstraints: const BoxConstraints(
          minWidth: 32,
          minHeight: 32,
        ),
      ),
      style: TextStyle(fontSize: 14, color: colors.textPrimary),
      onChanged: (v) => _onFieldChanged(v, _ActiveField.destination),
    );
  }

  // ---------- Shared read-only field ----------

  Widget _readOnlyField({
    required NusColorsData colors,
    required String label,
    Color? labelColor,
    Widget? icon,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[icon, const SizedBox(width: 8)],
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: labelColor ?? colors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 18, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dropdown body — extracted to a ConsumerWidget so the overlay has its own
// Consumer context for watching providers.
// ---------------------------------------------------------------------------

class _DropdownBody extends ConsumerWidget {
  final String query;
  final int minQueryLength;
  final Position? userPosition;
  final void Function(_SearchResult) onSelect;
  final VoidCallback onTapOutside;

  const _DropdownBody({
    required this.query,
    required this.minQueryLength,
    required this.userPosition,
    required this.onSelect,
    required this.onTapOutside,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    return TapRegion(
      onTapOutside: (_) => onTapOutside(),
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
          child: _buildContent(context, ref, colors),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    NusColorsData colors,
  ) {
    if (query.length < minQueryLength) {
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
              'Type $minQueryLength+ characters to search',
              style: TextStyle(color: colors.textMuted, fontSize: 14),
            ),
          ],
        ),
      );
    }

    final stopsAsync = ref.watch(stopsProvider);
    final buildingsAsync = ref.watch(buildingsProvider);

    return stopsAsync.when(
      loading: () => _loading(colors),
      error: (_, __) => _error(colors),
      data: (stops) => buildingsAsync.when(
        loading: () => _loading(colors),
        error: (_, __) => _error(colors),
        data: (buildings) {
          final results = _filter(stops, buildings);
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
          return ListView.separated(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: results.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, indent: 52, color: colors.borderLight),
            itemBuilder: (_, i) {
              final r = results[i];
              return FadeSlideIn(
                key: ValueKey('search_fade_${r.name}'),
                delay: Duration(milliseconds: 30 * i.clamp(0, 8)),
                child: _SearchResultTile(result: r, onTap: () => onSelect(r)),
              );
            },
          );
        },
      ),
    );
  }

  List<_SearchResult> _filter(List<BusStop> stops, List<Building> buildings) {
    final q = query.toLowerCase();
    final results = <_SearchResult>[];

    for (final stop in stops) {
      if (stop.longName.toLowerCase().contains(q) ||
          stop.shortName.toLowerCase().contains(q) ||
          stop.name.toLowerCase().contains(q) ||
          stop.caption.toLowerCase().contains(q)) {
        results.add(
          _SearchResult(
            name: stop.name,
            displayName: stop.longName.isNotEmpty ? stop.longName : stop.name,
            latitude: stop.latitude,
            longitude: stop.longitude,
            distanceMeters: _dist(stop.latitude, stop.longitude),
            isStop: true,
          ),
        );
      }
    }

    for (final b in buildings) {
      if (b.name.toLowerCase().contains(q)) {
        results.add(
          _SearchResult(
            name: b.name,
            displayName: b.name,
            latitude: b.latitude,
            longitude: b.longitude,
            distanceMeters: _dist(b.latitude, b.longitude),
            isStop: false,
          ),
        );
      }
    }

    return results.take(8).toList();
  }

  double _dist(double lat, double lng) {
    if (userPosition == null) return 0;
    const r = 6371e3;
    final dLat = (lat - userPosition!.latitude) * math.pi / 180;
    final dLng = (lng - userPosition!.longitude) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(userPosition!.latitude * math.pi / 180) *
            math.cos(lat * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Widget _loading(NusColorsData colors) => Padding(
    padding: const EdgeInsets.all(24),
    child: Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2, color: colors.primary),
      ),
    ),
  );

  Widget _error(NusColorsData colors) => Padding(
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

// ---------------------------------------------------------------------------
// Result tile
// ---------------------------------------------------------------------------

class _SearchResultTile extends StatelessWidget {
  final _SearchResult result;
  final VoidCallback onTap;

  const _SearchResultTile({required this.result, required this.onTap});

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
                result.distanceMeters < 1000
                    ? '${result.distanceMeters.round()}m'
                    : '${(result.distanceMeters / 1000).toStringAsFixed(1)}km',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}
