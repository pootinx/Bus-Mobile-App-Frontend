import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:flutter/foundation.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';

class AnalyticsService extends GetxService {
  static AnalyticsService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  FirebaseAnalytics? _analytics;

  @override
  void onInit() {
    super.onInit();
    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {}
  }

  void trackEvent(String eventType, {Map<String, dynamic>? data}) {
    final userId = AuthService.to.firebaseUser?.uid ?? 'anonymous';
    final eventData = (data ?? {})..['userId'] = userId;

    try {
      _db.collection('analyticsEvents').add({
        'userId': userId,
        'eventType': eventType,
        'data': data ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}

    try {
      _analytics?.logEvent(name: eventType, parameters: eventData.cast<String, Object>());
    } catch (_) {}
  }

  void setUserProperties({String? city, String? category}) {
    try {
      if (city != null) _analytics?.setUserProperty(name: 'city', value: city);
      if (category != null) _analytics?.setUserProperty(name: 'category', value: category);
    } catch (_) {}
  }

  void trackAppOpen() {
    trackEvent('app_open');
  }

  void trackSurveyStarted(String surveyId, {bool isMandatory = false}) {
    trackEvent('survey_started', data: {
      'surveyId': surveyId,
      'isMandatory': isMandatory,
    });
  }

  void trackSurveyCompleted(String surveyId, {required int questionCount}) {
    trackEvent('survey_completed', data: {
      'surveyId': surveyId,
      'questionCount': questionCount,
    });
  }

  void trackSurveySkipped(String surveyId) {
    trackEvent('survey_skipped', data: {
      'surveyId': surveyId,
    });
  }

  void trackBusLineSelected(String lineName, {String? city}) {
    trackEvent('bus_line_selected', data: {
      'lineName': lineName,
      'city': city ?? '',
    });
  }

  void trackNotificationClicked(String type, {String? surveyId}) {
    trackEvent('notification_clicked', data: {
      'type': type,
      'surveyId': surveyId ?? '',
    });
  }

  void trackOnboardingCompleted({
    required int age,
    required String city,
    required String status,
    String? gender,
  }) {
    trackEvent('onboarding_completed', data: {
      'age': age,
      'city': city,
      'professionalStatus': status,
      'gender': gender ?? '',
    });
  }

  void trackSearch(String from, String to) {
    trackEvent('route_search', data: {
      'from': from,
      'to': to,
    });
  }

  void trackError(String errorType, String message) {
    trackEvent('error', data: {
      'errorType': errorType,
      'message': message,
    });
  }

  void trackMandatorySurveyBlocked(String surveyId) {
    trackEvent('mandatory_survey_blocked', data: {
      'surveyId': surveyId,
    });
  }
}
