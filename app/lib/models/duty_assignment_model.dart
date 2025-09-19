class DutyAssignment {
  final String id;
  final String location;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  DutyAssignment({
    required this.id,
    required this.location,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory DutyAssignment.fromJson(Map<String, dynamic> json) {
    return DutyAssignment(
      id: json['id'],
      location: json['location'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      status: json['status'],
    );
  }
}