import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/learning_gap_model.dart';

/// Repository for managing candidate Learning Gap Detection requests.
class LearningGapRepository {
  LearningGapRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<LearningGapReport> getLearningGaps() async {
    final response =
        await _apiClient.get<Map<String, dynamic>>('/learning-gaps');

    final data = response.data;

    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return LearningGapReport.fromJson(data);
  }

  Future<List<Map<String, dynamic>>> getLearningHistory() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/learning/history');
    final data = response.data;

    if (data == null || data['reports'] is! List) {
      throw const ApiException('Invalid history response');
    }

    return List<Map<String, dynamic>>.from(data['reports']);
  }

  Future<LearningGapReport> getLearningReport(int sessionId) async {
    final response = await _apiClient.get<Map<String, dynamic>>('/learning/report/$sessionId');
    final data = response.data;

    if (data == null) {
      throw const ApiException('Empty report response');
    }

    return LearningGapReport.fromJson(data);
  }
}
