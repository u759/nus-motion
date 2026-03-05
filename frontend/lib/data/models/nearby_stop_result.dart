class NearbyStopResult {
  final String stopName;
  final String stopDisplayName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final int walkingMinutes;

  const NearbyStopResult({
    required this.stopName,
    required this.stopDisplayName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.walkingMinutes,
  });

  factory NearbyStopResult.fromJson(Map<String, dynamic> json) =>
      NearbyStopResult(
        stopName: json['stopName'] as String? ?? '',
        stopDisplayName: json['stopDisplayName'] as String? ?? '',
        latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
        walkingMinutes: (json['walkingMinutes'] as num?)?.toInt() ?? 0,
      );
}
