import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/account/account.dart';
import 'package:dcpl_user/features/auth/auth.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockMeRepository extends Mock implements MeRepository {}

class MockUser extends Mock implements fb.User {}

void main() {
  late MockAuthService auth;
  late MockMeRepository me;
  late MockUser firebaseUser;
  late SessionController session;
  late SetPasswordController controller;

  setUp(() {
    auth = MockAuthService();
    me = MockMeRepository();
    firebaseUser = MockUser();
    // A real session, pre-gated; constructing directly skips onInit so no auth
    // listener is attached — we only care about the flag it exposes.
    session = SessionController(auth, me)..mustChangePassword.value = true;
    controller = SetPasswordController(auth, me, session);
  });

  void enter(String password, [String? confirm]) {
    controller.passwordController.text = password;
    controller.confirmController.text = confirm ?? password;
  }

  test('rejects a too-short password without touching Firebase', () async {
    enter('short');

    final ok = await controller.submit();

    expect(ok, isFalse);
    expect(controller.error.value, 'Use at least 8 characters.');
    verifyNever(() => auth.currentUser);
  });

  test('rejects a mismatched confirmation', () async {
    enter('longenough', 'different1');

    final ok = await controller.submit();

    expect(ok, isFalse);
    expect(controller.error.value, "Passwords don't match.");
  });

  test(
    'updates the Firebase password, clears the flag, and lifts the gate',
    () async {
      when(() => auth.currentUser).thenReturn(firebaseUser);
      when(() => firebaseUser.updatePassword(any())).thenAnswer((_) async {});
      when(() => me.passwordChanged()).thenAnswer((_) async {});
      enter('newSecret1');

      final ok = await controller.submit();

      expect(ok, isTrue);
      verify(() => firebaseUser.updatePassword('newSecret1')).called(1);
      verify(() => me.passwordChanged()).called(1);
      expect(session.mustChangePassword.value, isFalse);
      expect(controller.error.value, isNull);
      expect(controller.isLoading.value, isFalse);
    },
  );

  test('surfaces a re-login message on requires-recent-login', () async {
    when(() => auth.currentUser).thenReturn(firebaseUser);
    when(
      () => firebaseUser.updatePassword(any()),
    ).thenThrow(fb.FirebaseAuthException(code: 'requires-recent-login'));
    enter('newSecret1');

    final ok = await controller.submit();

    expect(ok, isFalse);
    expect(
      controller.error.value,
      'For security, please log in again to change your password.',
    );
    verifyNever(() => me.passwordChanged());
    expect(session.mustChangePassword.value, isTrue);
  });

  test('does not clear the flag if passwordChanged() fails', () async {
    when(() => auth.currentUser).thenReturn(firebaseUser);
    when(() => firebaseUser.updatePassword(any())).thenAnswer((_) async {});
    when(() => me.passwordChanged()).thenThrow(Exception('boom'));
    enter('newSecret1');

    final ok = await controller.submit();

    expect(ok, isFalse);
    expect(
      controller.error.value,
      "Couldn't update your password. Please try again.",
    );
    expect(session.mustChangePassword.value, isTrue);
  });
}
