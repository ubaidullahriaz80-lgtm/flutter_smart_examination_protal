import '../../../data/models/user_model.dart';

/// States for [AuthBloc].
sealed class AuthState {
  const AuthState();
}

/// Before the initial session check has run.
class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A session check or login request is in flight.
class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);

  final UserModel user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);

  final String message;
}
