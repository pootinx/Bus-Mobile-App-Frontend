import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:bus_app/features/auth/services/onboarding_service.dart';
import 'package:bus_app/core/services/localization_service.dart';
import 'package:bus_app/core/controllers/theme_controller.dart';
import 'package:bus_app/features/auth/controllers/profile_controller.dart';
import 'package:bus_app/features/surveys/services/survey_service.dart';
import 'package:bus_app/features/analytics/services/analytics_service.dart';
import 'package:bus_app/features/notifications/services/notification_service.dart';
import 'package:bus_app/features/notifications/controllers/notification_controller.dart';

class AppInitService extends GetxService {
  Future<AppInitService> init() async {
    final sharedPrefs = await SharedPreferences.getInstance();
    Get.put(sharedPrefs);

    try {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      debugPrint('Firestore settings error: $e');
    }

    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      debugPrint("Error loading .env: $e");
    }

    try {
      final analytics = FirebaseAnalytics.instance;
      Get.put(analytics);
    } catch (e) {
      debugPrint("Analytics init error: $e");
    }

    Get.put(ProfileService());
    Get.put(AuthService());
    Get.put(OnboardingService());

    await Get.putAsync(() => SurveyService().init());
    Get.put(AnalyticsService());
    await Get.putAsync(() => NotificationService().init());
    Get.put(NotificationController());

    Get.put(ThemeController());
    Get.put(LocalizationService());
    Get.put(ProfileController());

    final user = AuthService.to.firebaseUser;
    if (user != null) {
      Get.find<NotificationController>().startListening();
    }

    return this;
  }
}