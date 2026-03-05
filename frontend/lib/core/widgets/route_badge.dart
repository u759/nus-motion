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
    final upper = code.toUpperCase();
    if (upper.startsWith('A')) return const Color(0xFF059669);
    if (upper.startsWith('B')) return const Color(0xFF135BEC);
    if (upper.startsWith('C')) return const Color(0xFFD97706);
    if (upper.startsWith('D')) return const Color(0xFFDC2626);
    if (upper.startsWith('E')) return const Color(0xFF7C3AED);
    if (upper.startsWith('K')) return const Color(0xFFEA580C);
    if (upper.startsWith('L')) return const Color(0xFF0891B2);
    return const Color(0xFF64748B);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? colorForRoute(routeCode);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
