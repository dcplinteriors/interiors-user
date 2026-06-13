import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_app.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;

  setUp(() => auth = MockAuthService());
  tearDown(Get.reset);

  testWidgets('renders the sign-in form', (tester) async {
    Get.put(LoginController(auth));
    await tester.pumpWidget(testApp(const LoginView()));

    expect(find.text('Supervisor Sign In'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('surfaces a friendly error when sign-in fails', (tester) async {
    when(() => auth.signIn(any(), any()))
        .thenThrow(FirebaseAuthException(code: 'invalid-credential'));
    Get.put(LoginController(auth));
    await tester.pumpWidget(testApp(const LoginView()));

    await tester.enterText(find.byType(TextField).at(0), 'supervisor@dcpl.test');
    await tester.enterText(find.byType(TextField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid email or password.'), findsOneWidget);
  });
}
