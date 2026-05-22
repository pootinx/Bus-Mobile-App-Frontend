import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/presentation/pages/login_screen/login_screen.dart';
import 'package:bus_app/features/auth/presentation/pages/verify_email_screen.dart';
import 'package:bus_app/features/auth/presentation/pages/post_signup_questions_page.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';
import 'package:bus_app/core/widgets/mandatory_survey_gate.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = Get.find<AuthService>();
  final _profileService = Get.find<ProfileService>();
  bool _profileLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    ever(_authService.isVerified, (bool verified) {
      if (verified) {
        _loadProfile();
      }
    });
  }

  Future<void> _loadProfile() async {
    final user = _authService.firebaseUser;
    if (user != null) {
      await user.reload();
      if (user.emailVerified) {
        await _profileService.fetchUserProfile(user);
      }
    }
    if (mounted) setState(() => _profileLoaded = true);
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _authService.firebaseUser;
      final isVerified = _authService.isVerified.value;

      if (user == null) {
        return const LoginScreen();
      }

      if (!isVerified) {
        return const VerifyEmailScreen();
      }

      if (!_profileLoaded) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      final profile = _profileService.user;
      if (profile == null || !profile.onboardingCompleted) {
        return const PostSignupQuestionsPage();
      }

      return const MandatorySurveyGate(
        child: MainPage(),
      );
    });
  }
}
