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

  factory LoadInfo.fromJson(Map<String, dynamic> json) {
    return LoadInfo(
      occupancy: (json['occupancy'] as num).toDouble(),
      crowdLevel: json['crowdLevel'] as String,
      capacity: (json['capacity'] as num).toInt(),
      ridership: (json['ridership'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'occupancy': occupancy,
      'crowdLevel': crowdLevel,
      'capacity': capacity,
      'ridership': ridership,
    };
  }
}

class ActiveBus {
  final String vehplate;
  final double lat;
  final double lng;
  final double speed;
  final double direction;
  final LoadInfo? loadInfo;

  const ActiveBus({
    required this.vehplate,
    required this.lat,
    required this.lng,
    required this.speed,
    required this.direction,
    this.loadInfo,
  });

  factory ActiveBus.fromJson(Map<String, dynamic> json) {
    return ActiveBus(
      vehplate: (json['vehplate'] ?? json['veh_plate']) as String,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      speed: (json['speed'] as num).toDouble(),
      direction: (json['direction'] as num).toDouble(),
      loadInfo: json['loadInfo'] != null
          ? LoadInfo.fromJson(json['loadInfo'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vehplate': vehplate,
      'lat': lat,
      'lng': lng,
      'speed': speed,
      'direction': direction,
      if (loadInfo != null) 'loadInfo': loadInfo!.toJson(),
    };
  }
}
