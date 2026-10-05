/// Events for [AuthBloc].
sealed class AuthEvent {
  const AuthEvent();
}

/// Dispatched by Splash on app start to check for a stored session.
class AuthCheckRequested extends AuthEvent {
  const AuthCheckRequested();
}

/// Dispatched by the Login form on submit.
class LoginRequested extends AuthEvent {
  const LoginRequested({required this.email, required this.password});

  final String email;
  final String password;
}

/// Dispatched from a Dashboard shell's logout action.
class LogoutRequested extends AuthEvent {
  const LogoutRequested();
}
