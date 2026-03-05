class DistanceFormatter {
  static String format(double meters) {
    if (meters < 1000) return '${meters.round()}m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
