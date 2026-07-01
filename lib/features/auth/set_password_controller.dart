import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../account/data/me_repository.dart';
import 'session_controller.dart';

/// Minimum length for a self-chosen supervisor password.
const kMinPasswordLength = 8;

/// Drives the blocking "set a new password" screen shown to supervisors who were
/// issued a temporary password. The user has just signed in, so Firebase allows
/// the in-session `currentUser.updatePassword(...)`; once it succeeds we clear
/// the server-side flag (`POST /me/password-changed`) and flip the session gate.
class SetPasswordController extends GetxController {
  SetPasswordController(this._auth, this._me, this._session);

  final AuthService _auth;
  final MeRepository _me;
  final SessionController _session;

  final passwordController = TextEditingController();
  final confirmController = TextEditingController();

  final isLoading = false.obs;
  final error = RxnString();

  /// Returns true when the password was changed and the gate cleared.
  Future<bool> submit() async {
    error.value = null;

    final password = passwordController.text;
    if (password.length < kMinPasswordLength) {
      error.value = 'Use at least $kMinPasswordLength characters.';
      return false;
    }
    if (password != confirmController.text) {
      error.value = 'Passwords don\'t match.';
      return false;
    }

    isLoading.value = true;
    try {
      final user = _auth.currentUser;
      if (user == null) {
        error.value = 'Your session expired. Please log in again.';
        return false;
      }
      await user.updatePassword(password);
      await _me.passwordChanged();
      // Flip the gate last: the router's refresh listenable navigates onward.
      _session.markPasswordChanged();
      return true;
    } on FirebaseAuthException catch (e) {
      error.value = _friendlyMessage(e.code);
      return false;
    } catch (_) {
      error.value = 'Couldn\'t update your password. Please try again.';
      return false;
    } finally {
      isLoading.value = false;
    }
  }

  String _friendlyMessage(String code) {
    switch (code) {
      case 'requires-recent-login':
        return 'For security, please log in again to change your password.';
      case 'weak-password':
        return 'That password is too weak. Choose a stronger one.';
      default:
        return 'Couldn\'t update your password. Please try again.';
    }
  }

  @override
  void onClose() {
    passwordController.dispose();
    confirmController.dispose();
    super.onClose();
  }
}
