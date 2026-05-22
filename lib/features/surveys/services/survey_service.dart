import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/surveys/models/survey_question.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:bus_app/features/analytics/services/analytics_service.dart';

class SurveyService extends GetxService {
  static SurveyService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<SurveyQuestion> questions = <SurveyQuestion>[].obs;
  final Rx<SurveyCampaign?> activeSurvey = Rx<SurveyCampaign?>(null);
  final RxBool isLoading = true.obs;
  final RxBool hasBlockedMandatorySurvey = false.obs;

  StreamSubscription? _surveySubscription;
  StreamSubscription? _blockedSubscription;

  Future<SurveyService> init() async {
    _setupAuthListener();
    await checkActiveSurvey();
    return this;
  }

  void _setupAuthListener() {
    ever(AuthService.to.firebaseUserObs, (_) {
      checkActiveSurvey();
    });
  }

  @override
  void onClose() {
    _surveySubscription?.cancel();
    _blockedSubscription?.cancel();
    super.onClose();
  }

  Future<void> checkActiveSurvey() async {
    final userId = _getUserId();
    if (userId == null) {
      activeSurvey.value = null;
      questions.clear();
      hasBlockedMandatorySurvey.value = false;
      _surveySubscription?.cancel();
      _blockedSubscription?.cancel();
      return;
    }

    _surveySubscription?.cancel();
    _blockedSubscription?.cancel();

    _surveySubscription = _db
        .collection('userSurveyStates')
        .where('uid', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        isLoading.value = true;
        try {
          final doc = snapshot.docs.first;
          final stateData = doc.data();
          final surveyId = stateData['surveyId'] as String?;
          final isMandatory = stateData['isMandatory'] as bool? ?? false;
          final blocked = stateData['blocked'] as bool? ?? false;

          if (surveyId != null) {
            final surveyDoc = await _db.collection('dailySurveys').doc(surveyId).get();
            if (surveyDoc.exists) {
              final survey = SurveyCampaign.fromFirestore(surveyDoc);

              if (survey.expiresAt != null && DateTime.now().isAfter(survey.expiresAt!)) {
                await _db
                    .collection('userSurveyStates')
                    .doc('${userId}_${surveyId}')
                    .update({'status': 'expired', 'blocked': false});
                activeSurvey.value = null;
                questions.clear();
                hasBlockedMandatorySurvey.value = false;
                isLoading.value = false;
                return;
              }

              activeSurvey.value = survey;
              hasBlockedMandatorySurvey.value = blocked && isMandatory;

              if (blocked && isMandatory) {
                Get.find<AnalyticsService>().trackMandatorySurveyBlocked(surveyId);
              }

              await loadQuestions(survey.questionIds);
            } else {
              activeSurvey.value = null;
              questions.clear();
              hasBlockedMandatorySurvey.value = false;
            }
          }
        } finally {
          isLoading.value = false;
        }
      } else {
        activeSurvey.value = null;
        questions.clear();
        hasBlockedMandatorySurvey.value = false;
        isLoading.value = false;
      }
    }, onError: (error) {
      debugPrint('SurveyService stream error: $error');
      isLoading.value = false;
    });
  }

  Future<void> loadQuestions(List<String> questionIds) async {
    if (questionIds.isEmpty) return;

    try {
      final snapshot = await _db
          .collection('surveyQuestions')
          .where(FieldPath.documentId, whereIn: questionIds)
          .get();

      questions.value = snapshot.docs
          .map((doc) => SurveyQuestion.fromFirestore(doc))
          .where((q) => q.isActive)
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    } catch (e) {
      debugPrint('loadQuestions error: $e');
    }
  }

  Future<bool> hasActiveSurvey() async {
    return activeSurvey.value != null;
  }

  Future<void> markSurveyAsCompleted() async {
    final userId = _getUserId();
    if (userId == null || activeSurvey.value == null) return;

    await _db
        .collection('userSurveyStates')
        .doc('${userId}_${activeSurvey.value!.id}')
        .update({
      'status': 'answered',
      'isAnswered': true,
      'blocked': false,
      'answeredAt': FieldValue.serverTimestamp(),
    });

    hasBlockedMandatorySurvey.value = false;
  }

  Future<void> submitAnswer(String questionId, String answer) async {
    final userId = _getUserId();
    if (userId == null || activeSurvey.value == null) return;

    final profile = Get.find<ProfileService>().user;
    final survey = activeSurvey.value!;
    final question = questions.firstWhereOrNull((q) => q.id == questionId);
    final now = DateTime.now();

    final answerData = {
      'uid': userId,
      'surveyId': survey.id,
      'questionId': questionId,
      'answer': answer,
      'answerValue': _normalizeAnswerValue(answer, question),
      'userMetadata': {
        'city': profile?.city ?? '',
        'age': profile?.age ?? 0,
        'gender': profile?.gender ?? '',
        'professionalStatus': profile?.professionalStatus ?? '',
        'mainLine': profile?.mainLine ?? '',
        'secondaryLine': profile?.secondaryLine ?? '',
        'boardingStation': profile?.boardingStation ?? '',
      },
      'surveyMetadata': {
        'surveyDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        'isMandatory': survey.isMandatory,
        'questionType': question?.type ?? 'text',
        'questionOrder': question?.order ?? 0,
      },
      'behaviorMetadata': {
        'deviceLanguage': Get.locale?.languageCode ?? 'en',
        'appVersion': '1.0.1',
        'platform': 'android',
      },
      'answeredAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('surveyAnswers').add(answerData);

    _logEvent('answer_submitted', {
      'surveyId': survey.id,
      'questionId': questionId,
      'city': profile?.city ?? '',
    });
  }

  Future<void> submitAllAnswers(Map<String, String> allAnswers) async {
    final userId = _getUserId();
    if (userId == null || activeSurvey.value == null) return;

    final profile = Get.find<ProfileService>().user;
    final survey = activeSurvey.value!;
    final now = DateTime.now();
    final batch = _db.batch();

    for (final entry in allAnswers.entries) {
      final question = questions.firstWhereOrNull((q) => q.id == entry.key);
      final answerRef = _db.collection('surveyAnswers').doc();

      batch.set(answerRef, {
        'uid': userId,
        'surveyId': survey.id,
        'questionId': entry.key,
        'answer': entry.value,
        'answerValue': _normalizeAnswerValue(entry.value, question),
        'userMetadata': {
          'city': profile?.city ?? '',
          'age': profile?.age ?? 0,
          'gender': profile?.gender ?? '',
          'professionalStatus': profile?.professionalStatus ?? '',
          'mainLine': profile?.mainLine ?? '',
          'secondaryLine': profile?.secondaryLine ?? '',
          'boardingStation': profile?.boardingStation ?? '',
        },
        'surveyMetadata': {
          'surveyDate': '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
          'isMandatory': survey.isMandatory,
          'questionType': question?.type ?? 'text',
          'questionOrder': question?.order ?? 0,
        },
        'behaviorMetadata': {
          'deviceLanguage': Get.locale?.languageCode ?? 'en',
          'appVersion': '1.0.1',
          'platform': 'android',
        },
        'answeredAt': FieldValue.serverTimestamp(),
      });
    }

    // Update user survey state
    final stateRef = _db
        .collection('userSurveyStates')
        .doc('${userId}_${survey.id}');

    batch.update(stateRef, {
      'status': 'answered',
      'blocked': false,
      'isAnswered': true,
      'answeredAt': FieldValue.serverTimestamp(),
    });

    // Mark notification as read
    final notifQuery = await _db
        .collection('inAppNotifications')
        .where('uid', isEqualTo: userId)
        .where('entityId', isEqualTo: survey.id)
        .limit(1)
        .get();

    if (notifQuery.docs.isNotEmpty) {
      batch.update(notifQuery.docs.first.reference, {
        'read': true,
        'clicked': true,
      });
    }

    await batch.commit();

    hasBlockedMandatorySurvey.value = false;

    _logEvent('survey_completed', {
      'surveyId': survey.id,
      'questionCount': allAnswers.length,
    });
  }

  dynamic _normalizeAnswerValue(String answer, SurveyQuestion? question) {
    if (question == null) return null;
    switch (question.type) {
      case 'rating':
        return int.tryParse(answer);
      case 'numeric':
        return num.tryParse(answer);
      case 'multiple_choice':
        return question.options.indexOf(answer) >= 0 ? question.options.indexOf(answer) + 1 : null;
      default:
        return null;
    }
  }

  Future<void> markNotificationOpened(String surveyId) async {
    final userId = _getUserId();
    if (userId == null) return;
    try {
      await _db
          .collection('userSurveyStates')
          .doc('${userId}_${surveyId}')
          .update({'notificationOpened': true, 'openedAt': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  String? _getUserId() {
    return AuthService.to.firebaseUser?.uid;
  }

  void _logEvent(String eventType, Map<String, dynamic> data) {
    try {
      final uid = _getUserId() ?? 'anonymous';
      _db.collection('analyticsEvents').add({
        'userId': uid,
        'eventType': eventType,
        'data': data,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }
}
