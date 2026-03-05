import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:frontend/app/theme.dart';

class BottomNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const BottomNavShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      extendBody: true,
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.neutralDark.withValues(alpha: 0.85),
              border: const Border(
                top: BorderSide(color: AppTheme.borderDark, width: 0.5),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _NavItem(
                      icon: Icons.map_outlined,
                      activeIcon: Icons.map,
                      label: 'Map',
                      isActive: navigationShell.currentIndex == 0,
                      onTap: () => _onTap(0),
                    ),
                    _NavItem(
                      icon: Icons.search_outlined,
                      activeIcon: Icons.search,
                      label: 'Search',
                      isActive: navigationShell.currentIndex == 1,
                      onTap: () => _onTap(1),
                    ),
                    _NavItem(
                      icon: Icons.bookmark_outline,
                      activeIcon: Icons.bookmark,
                      label: 'Saved',
                      isActive: navigationShell.currentIndex == 2,
                      onTap: () => _onTap(2),
                    ),
                    _NavItem(
                      icon: Icons.notifications_outlined,
                      activeIcon: Icons.notifications,
                      label: 'Alerts',
                      isActive: navigationShell.currentIndex == 3,
                      onTap: () => _onTap(3),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onTap(int index) {
    HapticFeedback.selectionClick();
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppTheme.primary : AppTheme.textMuted;

    return Semantics(
      label: label,
      selected: isActive,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          splashColor: AppTheme.primary.withValues(alpha: 0.1),
          highlightColor: AppTheme.primary.withValues(alpha: 0.05),
          child: SizedBox(
            width: 64,
            height: 52,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: AppTheme.durationFast,
                  child: Icon(
                    isActive ? activeIcon : icon,
                    key: ValueKey(isActive),
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: AppTheme.durationFast,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                  child: Text(label),
                ),
                const SizedBox(height: 2),
                // Active dot indicator
                AnimatedContainer(
                  duration: AppTheme.durationMedium,
                  curve: AppTheme.curve,
                  height: 3,
                  width: isActive ? 16 : 0,
                  decoration: BoxDecoration(
                    color: isActive ? AppTheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
