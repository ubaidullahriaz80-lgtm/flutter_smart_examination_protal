import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/core/routes/app_routes.dart';
import 'package:fsep/data/models/user_model.dart';
import 'package:fsep/data/repositories/auth_repository.dart';
import 'package:fsep/features/auth/bloc/auth_bloc.dart';
import 'package:fsep/features/auth/views/login_view.dart';

class _StubRepository extends AuthRepository {
  @override
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    return const UserModel(id: 'u1', role: UserRole.candidate);
  }
}

Widget _buildSubject() {
  return MaterialApp(
    routes: {
      AppRoutes.dashboard: (_) => const SizedBox(),
    },
    home: BlocProvider<AuthBloc>(
      create: (_) => AuthBloc(authRepository: _StubRepository()),
      child: const LoginView(),
    ),
  );
}

void main() {
  testWidgets('shows validation errors when submitted empty', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildSubject());

    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
  });

  testWidgets('accepts valid input without validation errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_buildSubject());

    await tester.enterText(find.byType(TextFormField).first, 'a@b.com');
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.tap(find.text('Log In'));
    await tester.pump();

    expect(find.text('Email is required'), findsNothing);
    expect(find.text('Password is required'), findsNothing);
  });
}
