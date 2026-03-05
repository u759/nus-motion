import 'package:flutter/material.dart';

class RouteBadge extends StatelessWidget {
  final String routeCode;
  final Color? backgroundColor;
  final double fontSize;

  const RouteBadge({
    super.key,
    required this.routeCode,
    this.backgroundColor,
    this.fontSize = 11,
  });

  static Color colorForRoute(String code) {
    switch (code.toUpperCase()) {
      case 'A1':
        return const Color(0xFFDC2626); // Red
      case 'A2':
        return const Color(0xFFEAB308); // Yellow
      case 'D1':
        return const Color(0xFFEC4899); // Pink
      case 'D2':
        return const Color(0xFF7C3AED); // Purple
      case 'K':
        return const Color(0xFF2563EB); // Blue
      case 'P':
        return const Color(0xFF6B7280); // Grey
      case 'R1':
        return const Color(0xFFEA580C); // Orange
      case 'R2':
        return const Color(0xFF16A34A); // Green
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? colorForRoute(routeCode);
    return Container(
      constraints: BoxConstraints(minWidth: fontSize * 3.5 + 19),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.directions_bus, size: fontSize + 1, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            routeCode,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
