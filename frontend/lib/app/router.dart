import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/map_discovery/map_discovery_screen.dart';
import 'package:frontend/features/search_routing/search_routing_screen.dart';
import 'package:frontend/features/search_routing/route_detail_screen.dart';
import 'package:frontend/features/active_transit/active_transit_screen.dart';
import 'package:frontend/features/favorites/favorites_screen.dart';
import 'package:frontend/features/alerts/alerts_screen.dart';
import 'package:frontend/app/theme.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) {
        return BottomNavShell(navigationShell: navigationShell);
      },
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const MapDiscoveryScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchRoutingScreen(),
              routes: [
                GoRoute(
                  path: 'detail',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return RouteDetailScreen(routeData: extra);
                  },
                ),
                GoRoute(
                  path: 'active',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final extra = state.extra as Map<String, dynamic>?;
                    return ActiveTransitScreen(tripData: extra);
                  },
                ),
              ],
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/alerts',
              builder: (context, state) => const AlertsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.borderLight, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: BottomNavigationBar(
              currentIndex: navigationShell.currentIndex,
              onTap: (index) => navigationShell.goBranch(
                index,
                initialLocation: index == navigationShell.currentIndex,
              ),
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textMuted,
              type: BottomNavigationBarType.fixed,
              selectedFontSize: 10,
              unselectedFontSize: 10,
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.explore_outlined),
                  activeIcon: Icon(Icons.explore),
                  label: 'EXPLORE',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.route_outlined),
                  activeIcon: Icon(Icons.route),
                  label: 'PLAN',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark_outline),
                  activeIcon: Icon(Icons.bookmark),
                  label: 'SAVED',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  activeIcon: Icon(Icons.notifications),
                  label: 'ALERTS',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
