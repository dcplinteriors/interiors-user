import 'package:dcpl_shared/dcpl_shared.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginController extends GetxController {
  LoginController(this._auth);

  final AuthService _auth;

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final isLoading = false.obs;
  final error = RxnString();

  Future<void> login() async {
    error.value = null;
    isLoading.value = true;
    try {
      // On success the auth state flips → the router's redirect navigates home.
      await _auth.signIn(emailController.text, passwordController.text);
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
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
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
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }
}
