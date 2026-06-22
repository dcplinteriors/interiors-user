import 'dart:typed_data';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:get/get.dart';

import '../material_requests/data/upload_service.dart';
import 'data/me_repository.dart';

/// The supervisor's account: loads the profile, resolves the avatar to a signed URL, and edits
/// name + photo (both persisted via `PATCH /me`).
class AccountController extends GetxController {
  AccountController(this._repo, this._uploads);

  final MeRepository _repo;
  final UploadService _uploads;

  final user = Rxn<User>();
  final isLoading = false.obs;
  final error = RxnString();

  /// True while a new avatar is uploading — the view shows a spinner over it.
  final photoUploading = false.obs;

  /// Resolved signed URL for the avatar (the stored `photoUrl` is an object path, not a URL).
  final photoUrl = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    error.value = null;
    try {
      final me = await _repo.get();
      user.value = me;
      await _resolvePhoto(me.photoUrl);
    } on ApiException catch (e) {
      error.value = e.message;
    } finally {
      isLoading.value = false;
    }
  }

  /// Updates the display name. Throws [ApiException] for the view to surface.
  Future<void> updateName(String name) async {
    user.value = await _repo.update(name: name);
  }

  /// Uploads a new avatar (scope `profile`), persists the path, and refreshes the resolved URL.
  /// Throws [ApiException] for the view to surface.
  Future<void> updatePhoto(Uint8List bytes, String contentType) async {
    photoUploading.value = true;
    try {
      final path = await _uploads.upload(
        kind: AttachmentKind.photo,
        bytes: bytes,
        contentType: contentType,
        scope: 'profile',
      );
      user.value = await _repo.update(photoUrl: path);
      await _resolvePhoto(path);
    } finally {
      photoUploading.value = false;
    }
  }

  Future<void> _resolvePhoto(String? path) async {
    if (path == null) {
      photoUrl.value = null;
      return;
    }
    try {
      photoUrl.value = await _repo.downloadUrl(path);
    } on ApiException catch (_) {
      photoUrl.value = null; // fall back to initials
    }
  }
}
