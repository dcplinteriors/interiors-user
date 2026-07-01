import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Supervisors sign in with a 10-digit phone number + password. Firebase
/// email/password auth runs underneath: the phone is mapped to a synthetic email
/// ([syntheticEmailForPhone]) before being handed to [AuthService.signIn].
class LoginController extends GetxController {
  LoginController(this._auth);

  final AuthService _auth;

  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final error = RxnString();

  Future<void> login() async {
    error.value = null;

    final email = syntheticEmailForPhone(phoneController.text);
    if (email == null) {
      error.value = 'Enter a valid 10-digit phone number.';
      return;
    }

    isLoading.value = true;
    try {
      // On success the auth state flips → the router's redirect navigates onward
      // (to the password-change gate or the app).
      await _auth.signIn(email, passwordController.text);
    } on FirebaseAuthException catch (e) {
      error.value = _friendlyMessage(e.code);
    } catch (_) {
      error.value = 'Sign-in failed. Please try again.';
    } finally {
      isLoading.value = false;
    }
  }

  String _friendlyMessage(String code) {
    switch (code) {
      // Every credential-shaped failure collapses to one message — we never hint
      // which half (phone vs password) was wrong.
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-email':
        return 'Incorrect phone number or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  @override
  void onClose() {
    phoneController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
