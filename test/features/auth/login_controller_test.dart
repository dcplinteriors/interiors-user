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
    controller.phoneController.text = '9876543210';
    controller.passwordController.text = 'secret';
  });

  test('signs in with the synthetic email derived from the phone', () async {
    when(() => auth.signIn(any(), any())).thenAnswer((_) async {});

    await controller.login();

    verify(
      () => auth.signIn('919876543210@phone.dcpl-interiors.app', 'secret'),
    ).called(1);
    expect(controller.error.value, isNull);
    expect(controller.isLoading.value, isFalse);
  });

  test('rejects an invalid phone without calling signIn', () async {
    controller.phoneController.text = '12345';

    await controller.login();

    verifyNever(() => auth.signIn(any(), any()));
    expect(controller.error.value, 'Enter a valid 10-digit phone number.');
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

  test(
    'collapses every credential failure to one phone-friendly message',
    () async {
      const msg = 'Incorrect phone number or password.';
      await expectMessage('invalid-credential', msg);
      await expectMessage('wrong-password', msg);
      await expectMessage('user-not-found', msg);
      await expectMessage('invalid-email', msg);
    },
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
