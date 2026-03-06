class Shuttle {
  final String name;
  final String busstopcode;
  final String arrivalTime;
  final String arrivalTimeVehPlate;
  final String nextArrivalTime;
  final String nextArrivalTimeVehPlate;
  final String passengers;
  final String nextPassengers;
  final String? towards;

  const Shuttle({
    required this.name,
    required this.busstopcode,
    required this.arrivalTime,
    required this.arrivalTimeVehPlate,
    required this.nextArrivalTime,
    required this.nextArrivalTimeVehPlate,
    required this.passengers,
    required this.nextPassengers,
    this.towards,
  });

  factory Shuttle.fromJson(Map<String, dynamic> json) => Shuttle(
    name: json['name'] as String? ?? '',
    busstopcode: json['busstopcode'] as String? ?? '',
    arrivalTime: json['arrivalTime'] as String? ?? '-',
    arrivalTimeVehPlate: json['arrivalTime_veh_plate'] as String? ?? '',
    nextArrivalTime: json['nextArrivalTime'] as String? ?? '-',
    nextArrivalTimeVehPlate: json['nextArrivalTime_veh_plate'] as String? ?? '',
    passengers: json['passengers'] as String? ?? '-',
    nextPassengers: json['nextPassengers'] as String? ?? '-',
    towards: json['towards'] as String?,
  );
}

class ShuttleServiceResult {
  final String? caption;
  final List<Shuttle> shuttles;

  const ShuttleServiceResult({this.caption, required this.shuttles});

  factory ShuttleServiceResult.fromJson(Map<String, dynamic> json) {
    final shuttleList = json['shuttles'] as List<dynamic>? ?? [];
    return ShuttleServiceResult(
      caption: json['caption'] as String?,
      shuttles: shuttleList
          .whereType<Map<String, dynamic>>()
          .map(Shuttle.fromJson)
          .toList(),
    );
  }
}
