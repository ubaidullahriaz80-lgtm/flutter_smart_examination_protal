/// Real authenticated-user profile (GET /api/user) — name/email/role for
/// dashboard display. Deliberately separate from [UserModel] (the
/// minimal id+role identity AuthBloc/session-restore already use) rather
/// than extending it, so this purely-additive read stays isolated from
/// the existing authentication/session machinery.
class UserProfileModel {
  const UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final int id;
  final String name;
  final String email;
  final String role;

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
    );
  }
}
