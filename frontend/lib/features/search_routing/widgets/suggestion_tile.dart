import 'package:flutter/material.dart';
import 'package:frontend/app/theme.dart';

class SuggestionTile extends StatelessWidget {
  final String name;
  final bool isCurrentLocation;
  final VoidCallback onTap;

  const SuggestionTile({
    super.key,
    required this.name,
    this.isCurrentLocation = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(
        isCurrentLocation ? Icons.my_location : Icons.location_on_outlined,
        color: isCurrentLocation ? AppColors.primary : AppColors.textMuted,
        size: 20,
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isCurrentLocation ? FontWeight.w600 : FontWeight.w400,
          color: AppColors.textPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
