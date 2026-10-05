import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/token_storage.dart';
import '../models/user_model.dart';
import '../models/user_profile_model.dart';

class AuthRepository {
  AuthRepository({
    ApiClient? apiClient,
    TokenStorage? tokenStorage,
  })  : _apiClient = apiClient ?? ApiClient.instance,
        _tokenStorage = tokenStorage ?? TokenStorage.instance;

  final ApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data;

    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    final token = data['jwt_token'] as String;
    final role = data['role'] as String;
    final userId = data['user_id'].toString();

    await _tokenStorage.saveSession(
      token: token,
      role: role,
      userId: userId,
    );

    return UserModel(
      id: userId,
      role: UserRole.fromApiValue(role),
    );
  }

  /// Real name/email/role for dashboard display — the existing
  /// GET /api/user endpoint (open to any authenticated role), not a new
  /// endpoint. Purely additive: no other auth/session behavior changes.
  Future<UserProfileModel> getProfile() async {
    final response = await _apiClient.get<Map<String, dynamic>>('/user');

    final data = response.data;
    if (data == null) {
      throw const ApiException('Empty response from server');
    }

    return UserProfileModel.fromJson(data);
  }

  Future<void> logout() {
    return _tokenStorage.clearSession();
  }

  Future<UserModel?> restoreSession() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      await _tokenStorage.clearSession();
      return null;
    }

    // IMPORTANT:
    // Your Laravel Sanctum token is NOT a JWT.
    // Therefore, do not call JwtUtils.isExpired(token).

    final role = await _tokenStorage.readRole();
    final userId = await _tokenStorage.readUserId();

    if (role == null || userId == null) {
      await _tokenStorage.clearSession();
      return null;
    }

    return UserModel(
      id: userId,
      role: UserRole.fromApiValue(role),
    );
  }
}