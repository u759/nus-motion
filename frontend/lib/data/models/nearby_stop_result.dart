class NearbyStopResult {
  final String stopName;
  final String stopDisplayName;
  final double latitude;
  final double longitude;
  final double distanceMeters;
  final double walkingMinutes;

  const NearbyStopResult({
    required this.stopName,
    required this.stopDisplayName,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    required this.walkingMinutes,
  });

  factory NearbyStopResult.fromJson(Map<String, dynamic> json) {
    return NearbyStopResult(
      stopName: json['stopName'] as String,
      stopDisplayName: json['stopDisplayName'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      walkingMinutes: (json['walkingMinutes'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'stopName': stopName,
      'stopDisplayName': stopDisplayName,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
      'walkingMinutes': walkingMinutes,
    };
  }
}
