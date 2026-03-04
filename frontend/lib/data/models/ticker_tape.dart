class TickerTape {
  final double accidentLatitude;
  final double accidentLongitude;
  final String affectedServiceIds;
  final String id;
  final String message;
  final String priority;
  final String status;

  const TickerTape({
    required this.accidentLatitude,
    required this.accidentLongitude,
    required this.affectedServiceIds,
    required this.id,
    required this.message,
    required this.priority,
    required this.status,
  });

  factory TickerTape.fromJson(Map<String, dynamic> json) {
    return TickerTape(
      accidentLatitude: (json['Accident_Latitude'] as num).toDouble(),
      accidentLongitude: (json['Accident_Longitude'] as num).toDouble(),
      affectedServiceIds: json['Affected_Service_Ids'] as String,
      id: json['ID'] as String,
      message: json['Message'] as String,
      priority: json['Priority'] as String,
      status: json['Status'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Accident_Latitude': accidentLatitude,
      'Accident_Longitude': accidentLongitude,
      'Affected_Service_Ids': affectedServiceIds,
      'ID': id,
      'Message': message,
      'Priority': priority,
      'Status': status,
    };
  }
}
