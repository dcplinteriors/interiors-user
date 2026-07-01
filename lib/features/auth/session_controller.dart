import 'dart:async';

import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:get/get.dart';

import '../account/data/me_repository.dart';

/// Holds the authenticated session's gate state for the router.
///
/// On every sign-in it loads the supervisor's profile (`GET /me`) to learn
/// whether [mustChangePassword] is set; the router redirects such users to the
/// blocking "set a new password" screen until [markPasswordChanged] clears it.
///
/// [profileResolved] lets the router hold navigation until the first profile
/// load settles, so a fresh login lands directly on the right screen instead of
/// flashing the app before the gate kicks in.
class SessionController extends GetxController {
  SessionController(this._auth, this._me);

  final AuthService _auth;
  final MeRepository _me;

  /// Whether the signed-in supervisor still owes us a self-chosen password.
  final mustChangePassword = false.obs;

  /// True once the first `/me` fetch for the current session has settled
  /// (success or failure). Reset to false on every auth-state change.
  final profileResolved = false.obs;

  StreamSubscription<fb.User?>? _sub;

  @override
  void onInit() {
    super.onInit();
    _sub = _auth.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(fb.User? user) async {
    if (user == null) {
      mustChangePassword.value = false;
      profileResolved.value = false;
      return;
    }
    // New (or re-)authentication: re-gate until the profile load settles.
    profileResolved.value = false;
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    try {
      final me = await _me.get();
      mustChangePassword.value = me.mustChangePassword;
    } catch (_) {
      // Don't lock a supervisor out of the app on a flaky/cold-start profile
      // fetch — fail open. The account screen surfaces its own load errors.
      mustChangePassword.value = false;
    } finally {
      profileResolved.value = true;
    }
  }

  /// Clears the gate after the supervisor sets their own password; the router's
  /// refresh listenable picks this up and routes them into the app.
  void markPasswordChanged() => mustChangePassword.value = false;

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}
