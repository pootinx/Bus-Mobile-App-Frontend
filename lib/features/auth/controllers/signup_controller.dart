
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';

class SignupController extends GetxController {
  final AuthService _authService = Get.find();

  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  void createUserWithEmailAndPassword() {
    _authService.createUserWithEmailAndPassword(
      emailController.text.trim(),
      passwordController.text.trim(),
      usernameController.text.trim(),
    );
  }
}
