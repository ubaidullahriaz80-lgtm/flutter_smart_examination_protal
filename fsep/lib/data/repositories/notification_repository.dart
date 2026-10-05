import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/network/api_client.dart';

/// Repository for registering device FCM tokens with the backend.
class NotificationRepository {
  NotificationRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient.instance;

  final ApiClient _apiClient;

  Future<void> registerToken(String token) async {
    final platform = kIsWeb
        ? 'web'
        : Platform.isAndroid
            ? 'android'
            : Platform.isIOS
                ? 'ios'
                : Platform.isWindows
                    ? 'windows'
                    : 'unknown';

    await _apiClient.post(
      '/device-tokens',
      data: {
        'token': token,
        'platform': platform,
      },
    );
  }

  Future<void> unregisterToken(String token) async {
    await _apiClient.delete(
      '/device-tokens',
      data: {'token': token},
    );
  }
}
