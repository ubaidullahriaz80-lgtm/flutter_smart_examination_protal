import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/biometrics/biometric_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  AuthBloc({
    required AuthRepository authRepository,
    NotificationRepository? notificationRepository,
    BiometricService? biometricService,
  })  : _authRepository = authRepository,
        _notificationRepository =
            notificationRepository ?? NotificationRepository(),
        _biometricService = biometricService ?? BiometricService.instance,
        super(const AuthInitial()) {
    on<AuthCheckRequested>(_onAuthCheckRequested);
    on<LoginRequested>(_onLoginRequested);
    on<LogoutRequested>(_onLogoutRequested);
  }

  final AuthRepository _authRepository;
  final NotificationRepository _notificationRepository;
  final BiometricService _biometricService;

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    final user = await _authRepository.restoreSession();
    if (user == null) {
      emit(const AuthUnauthenticated());
      return;
    }

    final biometricOk = await _biometricService.authenticate(
      reason: 'Confirm it\'s you to continue your session',
    );
    if (!biometricOk) {
      await _authRepository.logout();
      emit(const AuthUnauthenticated());
      return;
    }

    await _syncFcmToken();

    emit(AuthAuthenticated(user));
  }

  Future<void> _onLoginRequested(
    LoginRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(const AuthLoading());
    try {
      final user = await _authRepository.login(
        email: event.email,
        password: event.password,
      );

      await _syncFcmToken();

      emit(AuthAuthenticated(user));
    } on ApiException catch (error) {
      emit(AuthError(error.message));
    } catch (error) {
      emit(AuthError('Unexpected error: $error'));
    }
  }

  Future<void> _onLogoutRequested(
    LogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    final token = await NotificationService.getToken();
    if (token != null) {
      try {
        await _notificationRepository.unregisterToken(token);
      } catch (_) {}
    }

    await _authRepository.logout();
    emit(const AuthUnauthenticated());
  }

  Future<void> _syncFcmToken() async {
    final token = await NotificationService.getToken();
    if (token != null) {
      try {
        await _notificationRepository.registerToken(token);
      } catch (_) {}
    }
  }
}
