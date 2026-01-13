
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/authentication/services/auth_service.dart';

class LoginController extends GetxController {
  final AuthService _authService = Get.find();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void signInWithEmailAndPassword() {
    _authService.signInWithEmailAndPassword(
      emailController.text.trim(),
      passwordController.text.trim(),
    );
  }

  void onForgotPassword() {
    if (emailController.text.isNotEmpty) {
      _authService.sendPasswordResetEmail(emailController.text.trim());
    } else {
      Get.snackbar("Error", "Please enter your email to reset your password.", snackPosition: SnackPosition.BOTTOM);
    }
  }
}
