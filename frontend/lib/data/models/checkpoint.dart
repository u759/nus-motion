class CheckPoint {
  final String pointId;
  final double latitude;
  final double longitude;
  final int routeid;

  const CheckPoint({
    required this.pointId,
    required this.latitude,
    required this.longitude,
    required this.routeid,
  });

  factory CheckPoint.fromJson(Map<String, dynamic> json) => CheckPoint(
    pointId: json['PointID'] as String? ?? '',
    latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
    longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    routeid: (json['routeid'] as num?)?.toInt() ?? 0,
  );
}
