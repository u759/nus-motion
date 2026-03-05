class Announcement {
  final String id;
  final String text;
  final String status;
  final String priority;
  final String affectedServiceIds;

  const Announcement({
    required this.id,
    required this.text,
    required this.status,
    required this.priority,
    required this.affectedServiceIds,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
    id: json['ID'] as String? ?? '',
    text: json['Text'] as String? ?? '',
    status: json['Status'] as String? ?? '',
    priority: json['Priority'] as String? ?? '',
    affectedServiceIds: json['Affected_Service_Ids'] as String? ?? '',
  );
}
