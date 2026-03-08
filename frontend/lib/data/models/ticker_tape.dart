class TickerTape {
  final double? accidentLatitude;
  final double? accidentLongitude;
  final String affectedServiceIds;
  final String id;
  final String message;
  final String priority;
  final String status;

  /// Validity start time (from backend "displayFrom").
  final DateTime? displayFrom;

  /// Validity end time (from backend "displayTo").
  final DateTime? displayTo;

  /// When this ticker was created (from backend "createdOn").
  final DateTime? createdOn;

  /// Who created this ticker (from backend "createdBy").
  final String? createdBy;

  const TickerTape({
    this.accidentLatitude,
    this.accidentLongitude,
    required this.affectedServiceIds,
    required this.id,
    required this.message,
    required this.priority,
    required this.status,
    this.displayFrom,
    this.displayTo,
    this.createdOn,
    this.createdBy,
  });

  factory TickerTape.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? raw) {
      if (raw == null) return null;
      return DateTime.tryParse(raw);
    }

    return TickerTape(
      accidentLatitude: (json['Accident_Latitude'] as num?)?.toDouble(),
      accidentLongitude: (json['Accident_Longitude'] as num?)?.toDouble(),
      affectedServiceIds: json['Affected_Service_Ids'] as String? ?? '',
      id: json['ID'] as String? ?? '',
      message: json['Message'] as String? ?? '',
      priority: json['Priority'] as String? ?? '',
      status: json['Status'] as String? ?? '',
      displayFrom: parseDate(json['Display_From'] as String?),
      displayTo: parseDate(json['Display_To'] as String?),
      createdOn: parseDate(json['Created_On'] as String?),
      createdBy: json['Created_By'] as String?,
    );
  }
}
