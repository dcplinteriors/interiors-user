import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService auth;
  late LoginController controller;

  setUp(() {
    auth = MockAuthService();
    controller = LoginController(auth);
    controller.emailController.text = 'supervisor@dcpl.test';
    controller.passwordController.text = 'secret';
  });

  test('successful login calls signIn, clears error, resets loading', () async {
    when(() => auth.signIn(any(), any())).thenAnswer((_) async {});

    await controller.login();

    verify(() => auth.signIn('supervisor@dcpl.test', 'secret')).called(1);
    expect(controller.error.value, isNull);
    expect(controller.isLoading.value, isFalse);
  });

  Future<void> expectMessage(String code, String message) async {
    when(
      () => auth.signIn(any(), any()),
    ).thenThrow(FirebaseAuthException(code: code));
    await controller.login();
    expect(controller.error.value, message);
    expect(controller.isLoading.value, isFalse);
  }

  test('maps invalid-credential / wrong-password / user-not-found', () async {
    await expectMessage('invalid-credential', 'Invalid email or password.');
    await expectMessage('wrong-password', 'Invalid email or password.');
    await expectMessage('user-not-found', 'Invalid email or password.');
  });

  test(
    'maps invalid-email',
    () => expectMessage('invalid-email', 'Enter a valid email address.'),
  );

  test(
    'maps user-disabled',
    () => expectMessage('user-disabled', 'This account has been disabled.'),
  );

  test(
    'maps too-many-requests',
    () => expectMessage(
      'too-many-requests',
      'Too many attempts. Try again later.',
    ),
  );

  test(
    'maps an unknown Firebase code to the generic message',
    () => expectMessage('something-else', 'Sign-in failed. Please try again.'),
  );

  test('maps a non-Firebase error to the generic message', () async {
    when(() => auth.signIn(any(), any())).thenThrow(Exception('boom'));
    await controller.login();
    expect(controller.error.value, 'Sign-in failed. Please try again.');
    expect(controller.isLoading.value, isFalse);
  });
}
