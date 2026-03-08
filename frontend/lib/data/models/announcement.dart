class Announcement {
  final String id;
  final String text;
  final String status;
  final String priority;
  final String affectedServiceIds;

  /// Timestamp when the alert was created (from backend "createdOn").
  final DateTime? createdOn;

  /// Who created the alert (from backend "createdBy").
  final String? createdBy;

  const Announcement({
    required this.id,
    required this.text,
    required this.status,
    required this.priority,
    required this.affectedServiceIds,
    this.createdOn,
    this.createdBy,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    DateTime? parsedCreatedOn;
    final createdOnRaw = json['Created_On'];
    if (createdOnRaw != null) {
      parsedCreatedOn = DateTime.tryParse(createdOnRaw.toString());
    }

    return Announcement(
      id: json['ID'] as String? ?? '',
      text: json['Text'] as String? ?? '',
      status: json['Status'] as String? ?? '',
      priority: json['Priority'] as String? ?? '',
      affectedServiceIds: json['Affected_Service_Ids'] as String? ?? '',
      createdOn: parsedCreatedOn,
      createdBy: json['Created_By'] as String?,
    );
  }
}
