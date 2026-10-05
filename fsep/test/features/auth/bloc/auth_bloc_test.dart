import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/biometrics/biometric_service.dart';
import 'package:fsep/core/network/api_exception.dart';
import 'package:fsep/data/models/user_model.dart';
import 'package:fsep/data/repositories/auth_repository.dart';
import 'package:fsep/features/auth/bloc/auth_bloc.dart';
import 'package:fsep/features/auth/bloc/auth_event.dart';
import 'package:fsep/features/auth/bloc/auth_state.dart';

class _RestoresNullRepository extends AuthRepository {
  @override
  Future<UserModel?> restoreSession() async => null;

  @override
  Future<void> logout() async {}
}

class _RestoresUserRepository extends AuthRepository {
  bool loggedOut = false;

  @override
  Future<UserModel?> restoreSession() async =>
      const UserModel(id: 'u1', role: UserRole.examiner);

  @override
  Future<void> logout() async {
    loggedOut = true;
  }
}

class _PassingBiometricService extends BiometricService {
  @override
  Future<bool> authenticate({required String reason}) async => true;
}

class _FailingBiometricService extends BiometricService {
  @override
  Future<bool> authenticate({required String reason}) async => false;
}

class _SuccessfulLoginRepository extends AuthRepository {
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    return const UserModel(id: 'u1', role: UserRole.candidate);
  }
}

class _FailingLoginRepository extends AuthRepository {
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    throw const ApiException('Invalid credentials', statusCode: 401);
  }
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

void main() {
  test('AuthCheckRequested emits Loading then Unauthenticated when no session is stored', () async {
    final bloc = AuthBloc(authRepository: _RestoresNullRepository());
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthCheckRequested());
    await _flush();

    expect(states, [isA<AuthLoading>(), isA<AuthUnauthenticated>()]);

    await sub.cancel();
    await bloc.close();
  });

  test('AuthCheckRequested emits Loading then Authenticated when a valid session is restored and biometric check passes', () async {
    final bloc = AuthBloc(
      authRepository: _RestoresUserRepository(),
      biometricService: _PassingBiometricService(),
    );
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthCheckRequested());
    await _flush();

    expect(states, [isA<AuthLoading>(), isA<AuthAuthenticated>()]);
    expect((states.last as AuthAuthenticated).user.role, UserRole.examiner);

    await sub.cancel();
    await bloc.close();
  });

  test('AuthCheckRequested logs out and emits Unauthenticated when biometric check fails', () async {
    final repository = _RestoresUserRepository();
    final bloc = AuthBloc(
      authRepository: repository,
      biometricService: _FailingBiometricService(),
    );
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const AuthCheckRequested());
    await _flush();

    expect(states, [isA<AuthLoading>(), isA<AuthUnauthenticated>()]);
    expect(repository.loggedOut, isTrue);

    await sub.cancel();
    await bloc.close();
  });

  test('LoginRequested emits Loading then Authenticated on success', () async {
    final bloc = AuthBloc(authRepository: _SuccessfulLoginRepository());
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(email: 'a@b.com', password: 'secret'));
    await _flush();

    expect(states, [isA<AuthLoading>(), isA<AuthAuthenticated>()]);

    await sub.cancel();
    await bloc.close();
  });

  test('LoginRequested emits Loading then AuthError on failure', () async {
    final bloc = AuthBloc(authRepository: _FailingLoginRepository());
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LoginRequested(email: 'a@b.com', password: 'wrong'));
    await _flush();

    expect(states, [isA<AuthLoading>(), isA<AuthError>()]);
    expect((states.last as AuthError).message, 'Invalid credentials');

    await sub.cancel();
    await bloc.close();
  });

  test('LogoutRequested emits Unauthenticated', () async {
    final bloc = AuthBloc(authRepository: _RestoresNullRepository());
    final states = <AuthState>[];
    final sub = bloc.stream.listen(states.add);

    bloc.add(const LogoutRequested());
    await _flush();

    expect(states, [isA<AuthUnauthenticated>()]);

    await sub.cancel();
    await bloc.close();
  });
}
