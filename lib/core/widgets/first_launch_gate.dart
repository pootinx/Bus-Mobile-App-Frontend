import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_app/core/widgets/auth_wrapper.dart';
import 'package:bus_app/features/onboarding/presentation/pages/first_launch_onboarding_page.dart';

class FirstLaunchGate extends StatefulWidget {
  const FirstLaunchGate({super.key});

  @override
  State<FirstLaunchGate> createState() => _FirstLaunchGateState();
}

class _FirstLaunchGateState extends State<FirstLaunchGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    final prefs = Get.find<SharedPreferences>();
    final shown = prefs.getBool('onboardingShown') ?? false;
    if (!shown && mounted) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const FirstLaunchOnboardingPage(),
          fullscreenDialog: true,
        ),
      );
      if (result == true && mounted) {
        await prefs.setBool('onboardingShown', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const AuthWrapper();
  }
}
