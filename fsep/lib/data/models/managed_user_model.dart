import 'user_model.dart';

/// A user as managed by the System Administrator's User Management module
/// (GET/POST/PUT /api/users) — distinct from [UserModel], which represents
/// only the current authenticated session's minimal identity.
class ManagedUserModel {
  const ManagedUserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.departmentId,
    this.semester,
  });

  final int id;
  final String name;
  final String email;
  final UserRole role;
  final int? departmentId;
  final int? semester;

  factory ManagedUserModel.fromJson(Map<String, dynamic> json) {
    return ManagedUserModel(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: UserRole.fromApiValue(json['role'] as String),
      departmentId: json['department_id'] as int?,
      semester: json['semester'] as int?,
    );
  }
}
