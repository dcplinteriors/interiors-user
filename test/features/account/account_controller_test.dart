import 'dart:typed_data';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:dcpl_user/features/account/account.dart';
import 'package:dcpl_user/features/material_requests/data/upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMeRepository extends Mock implements MeRepository {}

class MockUploadService extends Mock implements UploadService {}

User user({String name = 'Ravi', String? photoUrl}) => User(
  uid: 's1',
  role: 'supervisor',
  name: name,
  email: 'r@x.test',
  photoUrl: photoUrl,
);

void main() {
  late MockMeRepository repo;
  late MockUploadService uploads;
  late AccountController controller;

  setUpAll(() {
    registerFallbackValue(AttachmentKind.photo);
    registerFallbackValue(Uint8List(0));
  });

  setUp(() {
    repo = MockMeRepository();
    uploads = MockUploadService();
    controller = AccountController(repo, uploads);
  });

  test('load() fetches the profile and resolves the avatar URL', () async {
    when(
      () => repo.get(),
    ).thenAnswer((_) async => user(photoUrl: 'profiles/s1/a.jpg'));
    when(
      () => repo.downloadUrl('profiles/s1/a.jpg'),
    ).thenAnswer((_) async => 'https://signed/a.jpg');
    await controller.load();
    expect(controller.user.value?.name, 'Ravi');
    expect(controller.photoUrl.value, 'https://signed/a.jpg');
  });

  test('load() with no photo leaves the avatar URL null', () async {
    when(() => repo.get()).thenAnswer((_) async => user());
    await controller.load();
    expect(controller.photoUrl.value, isNull);
  });

  test('updateName() persists and refreshes the user', () async {
    when(
      () => repo.update(name: 'Meera'),
    ).thenAnswer((_) async => user(name: 'Meera'));
    await controller.updateName('Meera');
    expect(controller.user.value?.name, 'Meera');
  });

  test(
    'updatePhoto() uploads with scope=profile, persists, and resolves the URL',
    () async {
      when(
        () => uploads.upload(
          kind: any(named: 'kind'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
          scope: any(named: 'scope'),
        ),
      ).thenAnswer((_) async => 'profiles/s1/new.jpg');
      when(
        () => repo.update(photoUrl: 'profiles/s1/new.jpg'),
      ).thenAnswer((_) async => user(photoUrl: 'profiles/s1/new.jpg'));
      when(
        () => repo.downloadUrl('profiles/s1/new.jpg'),
      ).thenAnswer((_) async => 'https://signed/new.jpg');

      await controller.updatePhoto(Uint8List.fromList([1, 2, 3]), 'image/jpeg');

      final scope = verify(
        () => uploads.upload(
          kind: any(named: 'kind'),
          bytes: any(named: 'bytes'),
          contentType: any(named: 'contentType'),
          scope: captureAny(named: 'scope'),
        ),
      ).captured.single;
      expect(scope, 'profile');
      expect(controller.photoUrl.value, 'https://signed/new.jpg');
      expect(controller.photoUploading.value, isFalse);
    },
  );
}
