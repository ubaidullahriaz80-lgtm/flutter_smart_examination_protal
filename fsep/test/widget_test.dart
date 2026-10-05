import 'package:flutter_test/flutter_test.dart';
import 'package:fsep/data/models/user_model.dart';
import 'package:fsep/data/repositories/auth_repository.dart';
import 'package:fsep/features/auth/views/login_view.dart';
import 'package:fsep/main.dart';

class _UnauthenticatedAuthRepository extends AuthRepository {
  @override
  Future<UserModel?> restoreSession() async => null;
}

void main() {
  testWidgets('Splash resolves to Login when no session is stored', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      FsepApp(authRepository: _UnauthenticatedAuthRepository()),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginView), findsOneWidget);
  });
}
