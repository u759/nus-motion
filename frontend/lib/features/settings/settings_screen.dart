import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/state/providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  void _showPrivacyPolicy(BuildContext context, NusColorsData colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textMuted.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: colors.border),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Privacy Policy\n\n'
                  'Last updated: March 12, 2026\n\n'
                  'NUS Motion is an unofficial campus transit app for the '
                  'National University of Singapore.\n\n'
                  'Information We Collect:\n'
                  '• Location Data: We use your device\'s location (when you '
                  'grant permission) to show nearby bus stops and provide '
                  'navigation. Your location is sent to our server only to '
                  'calculate nearby stops and is not stored.\n'
                  '• Local Storage: Favorite stops, favorite routes, recent '
                  'searches, and your theme preference are stored locally on '
                  'your device. This data never leaves your device.\n\n'
                  'Information We Do NOT Collect:\n'
                  '• We do not collect personal information (name, email, '
                  'phone).\n'
                  '• We do not use analytics or tracking.\n'
                  '• We do not use advertising.\n'
                  '• We do not share any data with third parties.\n\n'
                  'Third-Party Services:\n'
                  '• Google Maps: Used to display maps. Subject to Google\'s '
                  'Privacy Policy.\n'
                  '• NUS NextBus API: Used to fetch real-time bus data from '
                  'NUS.\n\n'
                  'Data Deletion:\n'
                  'You can clear all locally stored data by uninstalling the '
                  'app.\n\n'
                  'Contact:\n'
                  'For questions, contact ayden@u.nus.edu.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDataPrivacyDialog(BuildContext context, NusColorsData colors) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.security_outlined, color: colors.primary, size: 22),
            const SizedBox(width: 10),
            Text(
              'Data & Privacy',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ],
        ),
        content: Text(
          'NUS Motion stores your favorites and recent searches locally '
          'on your device. Location data is used only to find nearby '
          'stops and is not stored on our servers.',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(
                color: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final colors = context.nusColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        centerTitle: false,
        backgroundColor: colors.surface,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Appearance',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Column(
              children: [
                _ThemeTile(
                  title: 'Light',
                  subtitle: 'Always use light theme',
                  icon: Icons.light_mode_outlined,
                  selected: themeMode == AppThemeMode.light,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(AppThemeMode.light),
                ),
                Divider(height: 1, indent: 56, color: colors.border),
                _ThemeTile(
                  title: 'Dark',
                  subtitle: 'Always use dark theme',
                  icon: Icons.dark_mode_outlined,
                  selected: themeMode == AppThemeMode.dark,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(AppThemeMode.dark),
                ),
                Divider(height: 1, indent: 56, color: colors.border),
                _ThemeTile(
                  title: 'System',
                  subtitle: 'Follow system appearance',
                  icon: Icons.brightness_auto_outlined,
                  selected: themeMode == AppThemeMode.system,
                  onTap: () => ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(AppThemeMode.system),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'About',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.border, width: 0.5),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: colors.textMuted,
                        size: 22,
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NUS Motion',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Version 1.0.0',
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, indent: 56, color: colors.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Icon(
                    Icons.privacy_tip_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Privacy Policy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: colors.textPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.textMuted,
                    size: 20,
                  ),
                  onTap: () => _showPrivacyPolicy(context, colors),
                ),
                Divider(height: 1, indent: 56, color: colors.border),
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 2,
                  ),
                  leading: Icon(
                    Icons.security_outlined,
                    color: colors.textSecondary,
                  ),
                  title: Text(
                    'Data & Privacy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: colors.textPrimary,
                    ),
                  ),
                  trailing: Icon(
                    Icons.chevron_right,
                    color: colors.textMuted,
                    size: 20,
                  ),
                  onTap: () => _showDataPrivacyDialog(context, colors),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.nusColors;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      color: selected
          ? colors.primary.withValues(alpha: 0.06)
          : Colors.transparent,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Icon(
          icon,
          color: selected ? colors.primary : colors.textSecondary,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? colors.primary : colors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: colors.textSecondary, fontSize: 13),
        ),
        trailing: selected
            ? Icon(Icons.check_circle_rounded, color: colors.primary, size: 22)
            : Icon(
                Icons.radio_button_unchecked,
                color: colors.textMuted,
                size: 22,
              ),
        onTap: onTap,
      ),
    );
  }
}
