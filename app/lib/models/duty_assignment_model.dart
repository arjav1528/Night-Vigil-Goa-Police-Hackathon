class DutyAssignment {
  final String id;
  final String location;
  final double latitude;
  final double longitude;
  final double radius;
  final DateTime startTime;
  final DateTime endTime;
  final String status;

  DutyAssignment({
    required this.id,
    required this.location,
    required this.latitude,
    required this.longitude,
    required this.radius,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  factory DutyAssignment.fromJson(Map<String, dynamic> json) {
    return DutyAssignment(
      id: json['id'],
      location: json['location'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      status: json['status'],
    );
  }
}