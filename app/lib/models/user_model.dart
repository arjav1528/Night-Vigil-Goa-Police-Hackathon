class User {
  final String id;
  final String empid;
  final String role;
  final List<String> profileImages;

  User({
    required this.id,
    required this.empid,
    required this.role,
    required this.profileImages,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      empid: json['empid'],
      role: json['role'],
      profileImages: List<String>.from(json['profileImage']),
    );
  }
}