import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';

class DepartmentRepository {
  DepartmentRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<List<Map<String, dynamic>>> getDepartments() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/departments');
    if (response.data == null || response.data!['departments'] == null) {
      throw const ApiException('Empty response from server');
    }
    return List<Map<String, dynamic>>.from(response.data!['departments']);
  }

  Future<void> createDepartment({required String name, required String code}) async {
    await _apiClient.post('/departments', data: {'name': name, 'code': code});
  }

  Future<void> updateDepartment({required int id, required String name, required String code}) async {
    await _apiClient.put('/departments/$id', data: {'name': name, 'code': code});
  }

  Future<void> deleteDepartment(int id) async {
    await _apiClient.delete('/departments/$id');
  }
}
