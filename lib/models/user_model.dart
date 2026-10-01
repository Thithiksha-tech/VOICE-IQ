class UserModel {
  final int id;
  final String name;
  final String? registerNumber;
  final String? email;
  final bool emailVerified;
  final bool mustChangePassword;
  final String role;
  final String? token;

  UserModel({
    required this.id,
    required this.name,
    this.registerNumber,
    this.email,
    this.emailVerified = false,
    this.mustChangePassword = false,
    required this.role,
    this.token,
  });

  factory UserModel.fromJson(Map<String, dynamic> json, {String? token}) {
    return UserModel(
      id: json['user_id'] ?? json['id'] ?? 0,
      name: json['name'] ?? '',
      registerNumber: json['register_number'],
      email: json['email'],
      emailVerified: json['email_verified'] ?? false,
      mustChangePassword: json['must_change_password'] ?? false,
      role: json['role'] ?? 'student',
      token: token ?? json['access_token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'register_number': registerNumber,
      'email': email,
      'email_verified': emailVerified,
      'must_change_password': mustChangePassword,
      'role': role,
      'access_token': token,
    };
  }

  bool get isAdmin => role == 'admin';

  /// Students must verify an email and replace the default password before using the app.
  bool get needsSetup => !isAdmin && (!emailVerified || mustChangePassword);

  /// Register number for students, email for the admin.
  String get loginId => registerNumber ?? email ?? '';
}
