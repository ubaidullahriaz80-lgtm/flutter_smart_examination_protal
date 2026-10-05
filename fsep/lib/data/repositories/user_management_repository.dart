import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/csv_import_result.dart';
import '../models/managed_user_model.dart';
import '../models/user_model.dart';

/// System Administrator User Management (GET/POST/PUT /api/users).
/// The backend restricts these endpoints to the system_administrator role;
/// this repository does not perform any authorization itself.
class UserManagementRepository {
  UserManagementRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<ManagedUserModel>> getUsers() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/users');

    final data = response.data;

    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    final users = data['users'];

    if (users is! List) {
      throw const ApiException('Invalid users response');
    }

    return users
        .map((user) =>
            ManagedUserModel.fromJson(user as Map<String, dynamic>))
        .toList();
  }

  Future<ManagedUserModel> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
    int? departmentId,
    int? semester,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/users',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.apiValue,
        'department_id': departmentId,
        'semester': semester,
      },
    );

    final data = response.data;

    if (data == null || data['user'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ManagedUserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  Future<ManagedUserModel> updateUser({
    required int id,
    required String name,
    required String email,
    required UserRole role,
    int? departmentId,
    int? semester,
  }) async {
    final response = await _apiClient.put<Map<String, dynamic>>(
      '/users/$id',
      data: {
        'name': name,
        'email': email,
        'role': role.apiValue,
        'department_id': departmentId,
        'semester': semester,
      },
    );

    final data = response.data;

    if (data == null || data['user'] == null) {
      throw const ApiException('Empty response from server');
    }

    return ManagedUserModel.fromJson(data['user'] as Map<String, dynamic>);
  }

  /// Bulk-creates users from a CSV file (name, email, password, role
  /// columns). Every row is validated server-side with the exact same
  /// rules as [createUser]; invalid rows are reported back rather than
  /// failing the whole import.
  Future<CsvImportResult> importUsersCsv({
    required Uint8List bytes,
    required String fileName,
    int? departmentId,
    int? semester,
  }) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: fileName),
      if (departmentId != null) 'department_id': departmentId,
      if (semester != null) 'semester': semester,
    });

    final response = await _apiClient.post<Map<String, dynamic>>(
      '/users/import',
      data: formData,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return CsvImportResult.fromJson(data);
  }

  /// The backend rejects this with a 422 if the user has created any
  /// exam/question or has any exam session as a candidate, or if it's
  /// the caller's own account — surfaced to the caller as an
  /// ApiException like any other validation failure.
  Future<void> deleteUser(int id) async {
    await _apiClient.delete<void>('/users/$id');
  }
}
