class User {
  final String id;
  final String email;
  final String encryptedPassword;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.encryptedPassword,
    required this.createdAt,
  });

  factory User.fromFirestore(Map<String, dynamic> data, String id) {
    return User(
      id: id,
      email: data['email'] ?? '',
      encryptedPassword: data['encryptedPassword'] ?? '',
      createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'encryptedPassword': encryptedPassword,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}