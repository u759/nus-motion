import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/app/theme.dart';
import 'package:frontend/core/constants/app_constants.dart';
import 'package:frontend/core/utils/weather_mapper.dart';
import 'package:frontend/state/providers.dart';

/// Compact weather display showing icon and temperature.
///
/// Watches [weatherProvider] with NUS center coordinates.
/// Displays loading skeleton briefly, then icon + temp.
/// Gracefully hides on error.
class WeatherWidget extends ConsumerWidget {
  const WeatherWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.nusColors;
    final weatherAsync = ref.watch(
      weatherProvider((
        lat: AppConstants.nusLatitude,
        lng: AppConstants.nusLongitude,
      )),
    );

    // Match search bar height (TextField has vertical:14 + ~22px line = ~50px)
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 12),
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
      child: weatherAsync.when(
        data: (weather) {
          final info = WeatherMapper.fromCode(weather.weatherCode);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(info.icon, size: 20, color: colors.textSecondary),
              const SizedBox(width: 4),
              Text(
                '${weather.temperatureCelsius.round()}°',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ],
          );
        },
        loading: () => _buildLoadingSkeleton(colors),
        error: (_, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildLoadingSkeleton(NusColorsData colors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 28,
          height: 16,
          decoration: BoxDecoration(
            color: colors.surfaceMuted,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    );
  }
}
