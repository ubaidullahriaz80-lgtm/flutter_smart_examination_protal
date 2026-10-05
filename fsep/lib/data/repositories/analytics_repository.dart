import 'dart:typed_data';
import 'package:dio/dio.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../models/cohort_analytics_model.dart';

/// Repository for retrieving cohort and administrative assessment analytics.
class AnalyticsRepository {
  AnalyticsRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<CohortAnalytics> getCohortAnalytics({int? examId}) async {
    final response = await _apiClient.get<Map<String, dynamic>>(
      '/analytics/cohort',
      queryParameters: examId != null ? {'exam_id': examId} : null,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return CohortAnalytics.fromJson(data);
  }

  Future<Uint8List> getCohortPdf(int examId) async {
    final response = await _apiClient.get<List<int>>(
      '/exams/$examId/export/pdf',
      responseType: ResponseType.bytes,
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const ApiException('Empty response from server');
    }

    return Uint8List.fromList(data);
  }

  Future<Uint8List> getCohortExcel(int examId) async {
    final response = await _apiClient.get<List<int>>(
      '/exams/$examId/export/excel',
      responseType: ResponseType.bytes,
    );

    final data = response.data;
    if (data == null || data.isEmpty) {
      throw const ApiException('Empty response from server');
    }

    return Uint8List.fromList(data);
  }
}
