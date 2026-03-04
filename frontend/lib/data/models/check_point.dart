class CheckPoint {
  final int pointId;
  final double latitude;
  final double longitude;
  final String routeid;

  const CheckPoint({
    required this.pointId,
    required this.latitude,
    required this.longitude,
    required this.routeid,
  });

  factory CheckPoint.fromJson(Map<String, dynamic> json) {
    return CheckPoint(
      pointId: json['PointID'] as int,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      routeid: json['routeid'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'PointID': pointId,
      'latitude': latitude,
      'longitude': longitude,
      'routeid': routeid,
    };
  }
}
