class TickerTape {
  final double? accidentLatitude;
  final double? accidentLongitude;
  final String affectedServiceIds;
  final String id;
  final String message;
  final String priority;
  final String status;

  const TickerTape({
    this.accidentLatitude,
    this.accidentLongitude,
    required this.affectedServiceIds,
    required this.id,
    required this.message,
    required this.priority,
    required this.status,
  });

  factory TickerTape.fromJson(Map<String, dynamic> json) => TickerTape(
    accidentLatitude: (json['Accident_Latitude'] as num?)?.toDouble(),
    accidentLongitude: (json['Accident_Longitude'] as num?)?.toDouble(),
    affectedServiceIds: json['Affected_Service_Ids'] as String? ?? '',
    id: json['ID'] as String? ?? '',
    message: json['Message'] as String? ?? '',
    priority: json['Priority'] as String? ?? '',
    status: json['Status'] as String? ?? '',
  );
}
