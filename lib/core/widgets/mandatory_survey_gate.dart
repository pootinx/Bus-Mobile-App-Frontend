import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_app/features/surveys/services/survey_service.dart';
import 'package:bus_app/features/surveys/presentation/pages/survey_page.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';

class MandatorySurveyGate extends StatefulWidget {
  final Widget child;

  const MandatorySurveyGate({super.key, required this.child});

  @override
  State<MandatorySurveyGate> createState() => _MandatorySurveyGateState();
}

class _MandatorySurveyGateState extends State<MandatorySurveyGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOnLaunch());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkOnLaunch();
    }
  }

  Future<void> _checkOnLaunch() async {
    final uid = Get.find<AuthService>().firebaseUser?.uid;
    if (uid == null) return;

    try {
      final query = await FirebaseFirestore.instance
          .collection('userSurveyStates')
          .where('uid', isEqualTo: uid)
          .where('isMandatory', isEqualTo: true)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty && mounted) {
        final surveyId = query.docs.first.data()['surveyId'] as String;
        Get.to(
          () => SurveyPage(surveyId: surveyId),
          preventDuplicates: false,
        );
      }
    } catch (e) {
      debugPrint('MandatorySurveyGate check error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final surveyService = Get.find<SurveyService>();
      final hasBlockedSurvey = surveyService.hasBlockedMandatorySurvey.value;
      final isLoading = surveyService.isLoading.value;

      if (isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      }

      if (hasBlockedSurvey) {
        return const _MandatorySurveyBlocker();
      }

      return widget.child;
    });
  }
}

class _MandatorySurveyBlocker extends StatelessWidget {
  const _MandatorySurveyBlocker();

  @override
  Widget build(BuildContext context) {
    final surveyService = Get.find<SurveyService>();
    final surveyId = surveyService.activeSurvey.value?.id;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.primaryBlue,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 80,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Survey Required',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Please complete the mandatory survey to continue using the app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 48),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (surveyId != null) {
                          Get.to(() => SurveyPage(surveyId: surveyId));
                        } else {
                          _openActiveSurvey(surveyService);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Take Survey Now',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openActiveSurvey(SurveyService surveyService) async {
    final uid = Get.find<AuthService>().firebaseUser?.uid;
    if (uid == null) return;

    final query = await FirebaseFirestore.instance
        .collection('userSurveyStates')
        .where('uid', isEqualTo: uid)
        .where('isMandatory', isEqualTo: true)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      final sid = query.docs.first.data()['surveyId'] as String;
      Get.to(() => SurveyPage(surveyId: sid));
    }
  }
}
