class Shuttle {
  final String name;
  final String arrivalTime;
  final String arrivalTimeVehPlate;
  final String nextArrivalTime;
  final String nextArrivalTimeVehPlate;
  final String passengers;
  final String nextPassengers;

  const Shuttle({
    required this.name,
    required this.arrivalTime,
    required this.arrivalTimeVehPlate,
    required this.nextArrivalTime,
    required this.nextArrivalTimeVehPlate,
    required this.passengers,
    required this.nextPassengers,
  });

  factory Shuttle.fromJson(Map<String, dynamic> json) {
    return Shuttle(
      name: json['name'] as String,
      arrivalTime: json['arrivalTime'] as String,
      arrivalTimeVehPlate: json['arrivalTime_veh_plate'] as String,
      nextArrivalTime: json['nextArrivalTime'] as String,
      nextArrivalTimeVehPlate: json['nextArrivalTime_veh_plate'] as String,
      passengers: json['passengers'] as String,
      nextPassengers: json['nextPassengers'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'arrivalTime': arrivalTime,
      'arrivalTime_veh_plate': arrivalTimeVehPlate,
      'nextArrivalTime': nextArrivalTime,
      'nextArrivalTime_veh_plate': nextArrivalTimeVehPlate,
      'passengers': passengers,
      'nextPassengers': nextPassengers,
    };
  }
}
