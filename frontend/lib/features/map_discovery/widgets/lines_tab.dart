import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/utils/animations.dart';
import 'package:frontend/core/widgets/empty_state.dart';
import 'package:frontend/core/widgets/route_badge.dart';
import 'package:frontend/data/models/service_description.dart';
import 'package:frontend/state/providers.dart';

class LinesTab extends ConsumerStatefulWidget {
  final double userLat;
  final double userLng;
  final String? selectedRoute;
  final bool shouldScrollToSelection;
  final ValueChanged<String> onRouteSelected;

  const LinesTab({
    super.key,
    required this.userLat,
    required this.userLng,
    this.selectedRoute,
    this.shouldScrollToSelection = false,
    required this.onRouteSelected,
  });

  @override
  ConsumerState<LinesTab> createState() => _LinesTabState();
}

class _LinesTabState extends ConsumerState<LinesTab> {
  final _scrollController = ScrollController();
  final _itemKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String route) =>
      _itemKeys.putIfAbsent(route, () => GlobalKey());

  @override
  void didUpdateWidget(covariant LinesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldScrollToSelection &&
        widget.selectedRoute != null &&
        widget.selectedRoute != oldWidget.selectedRoute) {
      _scrollToSelected();
    }
  }

  void _scrollToSelected() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[widget.selectedRoute];
      if (key?.currentContext == null) return;
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final descriptions = ref.watch(serviceDescriptionsProvider);

    return descriptions.when(
      skipLoadingOnReload: true,
      data: (routes) {
        if (routes.isEmpty) {
          return const EmptyState(
            icon: Icons.route,
            title: 'No bus lines',
            subtitle: 'Service information unavailable',
          );
        }

        final selectedDesc = widget.selectedRoute != null
            ? routes.cast<ServiceDescription?>().firstWhere(
                (r) => r!.route == widget.selectedRoute,
                orElse: () => null,
              )
            : null;

        final sorted = _sortByProximity(routes);

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final isDetail =
                child.key == ValueKey('line_detail_${widget.selectedRoute}');
            final offset = isDetail
                ? Tween(begin: const Offset(0, 0.15), end: Offset.zero)
                : Tween(begin: const Offset(0, -0.05), end: Offset.zero);
            return SlideTransition(
              position: offset.animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: selectedDesc != null
              ? _LineDetailView(
                  key: ValueKey('line_detail_${widget.selectedRoute}'),
                  desc: selectedDesc,
                  onBack: () => widget.onRouteSelected(selectedDesc.route),
                )
              : _LineListView(
                  key: const ValueKey('line_list'),
                  sorted: sorted,
                  selectedRoute: widget.selectedRoute,
                  scrollController: _scrollController,
                  keyFor: _keyFor,
                  onRouteSelected: widget.onRouteSelected,
                ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'Failed to load lines',
            style: const TextStyle(color: AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  List<ServiceDescription> _sortByProximity(List<ServiceDescription> routes) {
    final withDist = <(ServiceDescription, double)>[];
    for (final desc in routes) {
      final pp = ref.watch(pickupPointsProvider(desc.route));
      double minDist = double.infinity;
      pp.whenData((points) {
        for (final p in points) {
          final d = _haversine(widget.userLat, widget.userLng, p.lat, p.lng);
          if (d < minDist) minDist = d;
        }
      });
      withDist.add((desc, minDist));
    }
    withDist.sort((a, b) => a.$2.compareTo(b.$2));
    return withDist.map((e) => e.$1).toList();
  }

  static double _haversine(double lat1, double lng1, double lat2, double lng2) {
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
}

// ─── Line List View ───────────────────────────────────────────

class _LineListView extends StatelessWidget {
  final List<ServiceDescription> sorted;
  final String? selectedRoute;
  final ScrollController scrollController;
  final GlobalKey Function(String) keyFor;
  final ValueChanged<String> onRouteSelected;

  const _LineListView({
    super.key,
    required this.sorted,
    this.selectedRoute,
    required this.scrollController,
    required this.keyFor,
    required this.onRouteSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      key: const PageStorageKey('lines_tab_list'),
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: sorted.length,
      itemBuilder: (context, index) {
        final desc = sorted[index];
        final isSelected = selectedRoute == desc.route;
        return FadeSlideIn(
          key: ValueKey('fade_${desc.route}'),
          delay: Duration(milliseconds: 40 * index.clamp(0, 8)),
          child: _LineItem(
            key: keyFor(desc.route),
            desc: desc,
            isSelected: isSelected,
            onTap: () => onRouteSelected(desc.route),
          ),
        );
      },
    );
  }
}

// ─── Line Detail View (full panel) ───────────────────────────

class _LineDetailView extends ConsumerWidget {
  final ServiceDescription desc;
  final VoidCallback onBack;

  const _LineDetailView({super.key, required this.desc, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routeColor = RouteBadge.colorForRoute(desc.route);
    final activeBuses = ref.watch(activeBusesProvider(desc.route));
    final pickupPoints = ref.watch(pickupPointsProvider(desc.route));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 20, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                behavior: HitTestBehavior.opaque,
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              RouteBadge(routeCode: desc.route, fontSize: 15),
              const SizedBox(width: 14),
              Expanded(
                child: _RoutePathText(
                  text: desc.routeDescription.isNotEmpty
                      ? desc.routeDescription
                      : desc.routeLongName,
                  routeColor: routeColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
        // Content
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              // Active buses section
              _SectionHeader(
                icon: Icons.directions_bus,
                title: 'Active Buses',
                color: routeColor,
              ),
              const SizedBox(height: 8),
              activeBuses.when(
                skipLoadingOnReload: true,
                data: (buses) {
                  if (buses.isEmpty) {
                    return _InfoCard(
                      child: const Text(
                        'No buses currently in service',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (int i = 0; i < buses.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: i < buses.length - 1 ? 4 : 0,
                          ),
                          child: _ActiveBusRow(
                            plate: buses[i].vehPlate,
                            speed: buses[i].speed,
                            crowdLevel: buses[i].loadInfo?.crowdLevel,
                            ridership: buses[i].loadInfo?.ridership,
                            capacity: buses[i].loadInfo?.capacity,
                            routeColor: routeColor,
                          ),
                        ),
                    ],
                  );
                },
                loading: () => const _InfoCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => const _InfoCard(
                  child: Text(
                    'Failed to load buses',
                    style: TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Pickup points / stops section
              _SectionHeader(
                icon: Icons.pin_drop,
                title: 'Stops',
                color: routeColor,
              ),
              const SizedBox(height: 8),
              pickupPoints.when(
                skipLoadingOnReload: true,
                data: (points) {
                  if (points.isEmpty) {
                    return _InfoCard(
                      child: const Text(
                        'No stop information available',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textMuted,
                        ),
                      ),
                    );
                  }
                  final sorted = [...points]
                    ..sort((a, b) => a.seq.compareTo(b.seq));
                  return _InfoCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (int i = 0; i < sorted.length; i++) ...[
                          _PickupPointRow(
                            index: i + 1,
                            name: sorted[i].longName.isNotEmpty
                                ? sorted[i].longName
                                : sorted[i].pickupname,
                            shortName: sorted[i].shortName,
                            routeColor: routeColor,
                            isFirst: i == 0,
                            isLast: i == sorted.length - 1,
                          ),
                          if (i < sorted.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(left: 15),
                              child: Container(
                                width: 2,
                                height: 12,
                                color: routeColor.withValues(alpha: 0.2),
                              ),
                            ),
                        ],
                      ],
                    ),
                  );
                },
                loading: () => const _InfoCard(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (_, __) => const _InfoCard(
                  child: Text(
                    'Failed to load stops',
                    style: TextStyle(fontSize: 13, color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Section Header ──────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

// ─── Info Card ───────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;

  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: child,
    );
  }
}

// ─── Active Bus Row ──────────────────────────────────────────

class _ActiveBusRow extends StatelessWidget {
  final String plate;
  final int speed;
  final String? crowdLevel;
  final int? ridership;
  final int? capacity;
  final Color routeColor;

  const _ActiveBusRow({
    required this.plate,
    required this.speed,
    this.crowdLevel,
    this.ridership,
    this.capacity,
    required this.routeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: routeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.directions_bus, size: 16, color: routeColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plate,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$speed km/h',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (crowdLevel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _crowdColor(crowdLevel!).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                crowdLevel!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _crowdColor(crowdLevel!),
                ),
              ),
            ),
          ],
          if (ridership != null && capacity != null && capacity! > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$ridership/$capacity',
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  static Color _crowdColor(String level) {
    switch (level.toLowerCase()) {
      case 'low':
        return AppColors.success;
      case 'medium':
        return const Color(0xFFEAB308);
      case 'high':
        return AppColors.error;
      default:
        return AppColors.textMuted;
    }
  }
}

// ─── Pickup Point Row ────────────────────────────────────────

class _PickupPointRow extends StatelessWidget {
  final int index;
  final String name;
  final String shortName;
  final Color routeColor;
  final bool isFirst;
  final bool isLast;

  const _PickupPointRow({
    required this.index,
    required this.name,
    required this.shortName,
    required this.routeColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomPaint(
            painter: _TimelinePainter(
              routeColor: routeColor,
              isFirst: isFirst,
              isLast: isLast,
            ),
            child: const SizedBox(width: 30),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (shortName.isNotEmpty && shortName != name)
                    Text(
                      shortName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Line Item (list view) ───────────────────────────────────

class _LineItem extends ConsumerWidget {
  final ServiceDescription desc;
  final bool isSelected;
  final VoidCallback onTap;

  const _LineItem({
    super.key,
    required this.desc,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBuses = ref.watch(activeBusesProvider(desc.route));
    final routeColor = RouteBadge.colorForRoute(desc.route);

    final selectedBg = Color.alphaBlend(
      routeColor.withValues(alpha: 0.06),
      AppColors.surface,
    );
    final selectedBorder = Color.alphaBlend(
      routeColor.withValues(alpha: 0.3),
      AppColors.surface,
    );

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? selectedBorder : AppColors.borderLight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              RouteBadge(routeCode: desc.route, fontSize: 13),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _RoutePathText(
                      text: desc.routeDescription.isNotEmpty
                          ? desc.routeDescription
                          : desc.routeLongName,
                      routeColor: routeColor,
                      fontSize: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              activeBuses.when(
                data: (buses) {
                  if (buses.isEmpty) {
                    return const Text(
                      'No buses',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    );
                  }
                  return AnimatedSwitcherDefaults(
                    child: Container(
                      key: ValueKey(buses.length),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${buses.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  );
                },
                loading: () => const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(width: 4),
              Icon(
                isSelected ? Icons.map : Icons.chevron_right,
                size: 18,
                color: isSelected ? routeColor : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Route Path Text ─────────────────────────────────────────

class _RoutePathText extends StatelessWidget {
  final String text;
  final Color routeColor;
  final double fontSize;

  const _RoutePathText({
    required this.text,
    required this.routeColor,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    final segments = text
        .split('>')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    final child = Text.rich(
      TextSpan(
        children: [
          for (int i = 0; i < segments.length; i++) ...[
            TextSpan(
              text: segments[i],
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (i < segments.length - 1)
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: Icon(
                    Icons.arrow_forward_ios,
                    size: fontSize * 0.6,
                    color: routeColor.withValues(alpha: 0.45),
                  ),
                ),
              ),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
    );

    return _MarqueeScroll(child: child);
  }
}

class _MarqueeScroll extends StatefulWidget {
  final Widget child;
  const _MarqueeScroll({required this.child});

  @override
  State<_MarqueeScroll> createState() => _MarqueeScrollState();
}

class _MarqueeScrollState extends State<_MarqueeScroll>
    with SingleTickerProviderStateMixin {
  final _scrollController = ScrollController();
  late final AnimationController _fadeController;
  bool _overflows = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  void _checkOverflow() {
    if (!mounted || !_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0 && !_overflows) {
      _overflows = true;
      _runCycle();
    }
  }

  Future<void> _runCycle() async {
    while (mounted && _overflows) {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      final maxScroll = _scrollController.position.maxScrollExtent;
      final ms = (maxScroll * 12).toInt().clamp(800, 4000);
      await _scrollController.animateTo(
        maxScroll,
        duration: Duration(milliseconds: ms),
        curve: Curves.linear,
      );
      if (!mounted) return;

      await Future.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      await _fadeController.animateTo(0);
      if (!mounted) return;

      _scrollController.jumpTo(0);

      await _fadeController.animateTo(1);
      if (!mounted) return;
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }
}

// ─── Timeline Painter ────────────────────────────────────────

class _TimelinePainter extends CustomPainter {
  final Color routeColor;
  final bool isFirst;
  final bool isLast;

  _TimelinePainter({
    required this.routeColor,
    required this.isFirst,
    required this.isLast,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    const circleRadius = 5.0;
    const borderWidth = 2.0;
    const lineWidth = 2.0;

    final linePaint = Paint()
      ..color = routeColor.withValues(alpha: 0.2)
      ..strokeWidth = lineWidth
      ..style = PaintingStyle.stroke;

    // Draw vertical line segments
    if (!isFirst) {
      canvas.drawLine(
        Offset(centerX, 0),
        Offset(centerX, centerY - circleRadius),
        linePaint,
      );
    }
    if (!isLast) {
      canvas.drawLine(
        Offset(centerX, centerY + circleRadius),
        Offset(centerX, size.height),
        linePaint,
      );
    }

    // Draw circle fill
    final fillPaint = Paint()
      ..color = (isFirst || isLast) ? routeColor : AppColors.surface
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, centerY), circleRadius, fillPaint);

    // Draw circle border
    final borderPaint = Paint()
      ..color = routeColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(
      Offset(centerX, centerY),
      circleRadius - borderWidth / 2,
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      routeColor != old.routeColor ||
      isFirst != old.isFirst ||
      isLast != old.isLast;
}
