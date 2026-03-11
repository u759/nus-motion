import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/features/map_discovery/map_discovery_screen.dart';
import 'package:frontend/features/map_discovery/models/navigation_state.dart';
import 'package:frontend/features/favorites/favorites_screen.dart';
import 'package:frontend/features/alerts/alerts_screen.dart';
import 'package:frontend/features/settings/settings_screen.dart';
import 'package:frontend/app/theme.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  restorationScopeId: 'router',
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
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

class BottomNavShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch navigation state to handle back for explore tab
    final navState = ref.watch(navigationStateProvider);
    final colors = context.nusColors;

    // Allow system pop only when navigation state is idle OR not on explore tab
    final canPop =
        navigationShell.currentIndex != 0 ||
        navState.status == NavigationStatus.idle;

    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        // Only handle custom back for explore tab (index 0) with active navigation
        if (navigationShell.currentIndex == 0) {
          if (navState.route != null) {
            // In route detail → go back to suggestions
            ref.read(navigationStateProvider.notifier).deselectRoute();
          } else if (navState.destination != null) {
            // In suggestions → go back to explore
            ref.read(navigationStateProvider.notifier).cancelNavigation();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: navigationShell,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.border, width: 1)),
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.06),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: BottomNavigationBar(
                currentIndex: navigationShell.currentIndex,
                onTap: (index) => navigationShell.goBranch(
                  index,
                  initialLocation: index == navigationShell.currentIndex,
                ),
                elevation: 0,
                backgroundColor: Colors.transparent,
                selectedItemColor: colors.primary,
                unselectedItemColor: colors.textMuted,
                type: BottomNavigationBarType.fixed,
                selectedFontSize: 11,
                unselectedFontSize: 11,
                selectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w400,
                ),
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.near_me_outlined),
                    activeIcon: Icon(Icons.near_me),
                    label: 'Explore',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.bookmark_outline),
                    activeIcon: Icon(Icons.bookmark),
                    label: 'Saved',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.notifications_outlined),
                    activeIcon: Icon(Icons.notifications),
                    label: 'Alerts',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.settings_outlined),
                    activeIcon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
