class LoadInfo {
  final double occupancy;
  final String crowdLevel;
  final int capacity;
  final int ridership;

  const LoadInfo({
    required this.occupancy,
    required this.crowdLevel,
    required this.capacity,
    required this.ridership,
  });

  factory LoadInfo.fromJson(Map<String, dynamic> json) => LoadInfo(
    occupancy: (json['occupancy'] as num?)?.toDouble() ?? 0,
    crowdLevel: json['crowdLevel'] as String? ?? 'Unknown',
    capacity: (json['capacity'] as num?)?.toInt() ?? 0,
    ridership: (json['ridership'] as num?)?.toInt() ?? 0,
  );
}

class ActiveBus {
  final String vehPlate;
  final double lat;
  final double lng;
  final int speed;
  final double direction;
  final LoadInfo? loadInfo;

  const ActiveBus({
    required this.vehPlate,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.direction,
    this.loadInfo,
  });

  factory ActiveBus.fromJson(Map<String, dynamic> json) => ActiveBus(
    vehPlate: (json['vehplate'] ?? json['veh_plate'] ?? '') as String,
    lat: (json['lat'] as num?)?.toDouble() ?? 0,
    lng: (json['lng'] as num?)?.toDouble() ?? 0,
    speed: (json['speed'] as num?)?.toInt() ?? 0,
    direction: (json['direction'] as num?)?.toDouble() ?? 0,
    loadInfo: json['loadInfo'] != null
        ? LoadInfo.fromJson(json['loadInfo'] as Map<String, dynamic>)
        : null,
  );
}
