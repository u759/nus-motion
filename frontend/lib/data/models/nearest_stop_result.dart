class NearestStopResult {
  final String buildingName;
  final double buildingLatitude;
  final double buildingLongitude;
  final String busStopName;
  final String busStopDisplayName;
  final double busStopLatitude;
  final double busStopLongitude;
  final double distanceMeters;

  const NearestStopResult({
    required this.buildingName,
    required this.buildingLatitude,
    required this.buildingLongitude,
    required this.busStopName,
    required this.busStopDisplayName,
    required this.busStopLatitude,
    required this.busStopLongitude,
    required this.distanceMeters,
  });

  factory NearestStopResult.fromJson(Map<String, dynamic> json) =>
      NearestStopResult(
        buildingName: json['buildingName'] as String? ?? '',
        buildingLatitude: (json['buildingLatitude'] as num?)?.toDouble() ?? 0,
        buildingLongitude: (json['buildingLongitude'] as num?)?.toDouble() ?? 0,
        busStopName: json['busStopName'] as String? ?? '',
        busStopDisplayName: json['busStopDisplayName'] as String? ?? '',
        busStopLatitude: (json['busStopLatitude'] as num?)?.toDouble() ?? 0,
        busStopLongitude: (json['busStopLongitude'] as num?)?.toDouble() ?? 0,
        distanceMeters: (json['distanceMeters'] as num?)?.toDouble() ?? 0,
      );
}
