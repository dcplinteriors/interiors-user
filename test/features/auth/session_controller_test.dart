import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/account/account.dart';
import 'package:dcpl_user/features/auth/auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthService extends Mock implements AuthService {}

class MockMeRepository extends Mock implements MeRepository {}

User supervisor({bool mustChangePassword = false}) => User(
  uid: 's1',
  role: 'supervisor',
  name: 'Ravi',
  mustChangePassword: mustChangePassword,
);

void main() {
  late MockAuthService auth;
  late MockMeRepository me;
  late SessionController session;

  setUp(() {
    auth = MockAuthService();
    me = MockMeRepository();
    session = SessionController(auth, me);
  });

  test('refreshProfile resolves and sets the gate when must-change', () async {
    when(
      () => me.get(),
    ).thenAnswer((_) async => supervisor(mustChangePassword: true));

    await session.refreshProfile();

    expect(session.profileResolved.value, isTrue);
    expect(session.mustChangePassword.value, isTrue);
  });

  test('refreshProfile leaves the gate down for a normal profile', () async {
    when(() => me.get()).thenAnswer((_) async => supervisor());

    await session.refreshProfile();

    expect(session.profileResolved.value, isTrue);
    expect(session.mustChangePassword.value, isFalse);
  });

  test('refreshProfile fails open (resolved, no gate) on error', () async {
    when(() => me.get()).thenThrow(Exception('cold start'));

    await session.refreshProfile();

    expect(session.profileResolved.value, isTrue);
    expect(session.mustChangePassword.value, isFalse);
  });

  test('markPasswordChanged lifts the gate', () {
    session.mustChangePassword.value = true;

    session.markPasswordChanged();

    expect(session.mustChangePassword.value, isFalse);
  });
}
