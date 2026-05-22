import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/surveys/presentation/pages/survey_page.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';
import 'package:bus_app/features/analytics/services/analytics_service.dart';

class NotificationService extends GetxService {
  static NotificationService get to => Get.find();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxBool hasPermission = false.obs;

  Future<NotificationService> init() async {
    _initLocalNotifications();
    await _requestPermission();
    await _getFCMToken();
    _setupListeners();
    ever(AuthService.to.firebaseUserObs, (_) => _getFCMToken());
    return this;
  }

  Future<void> _requestPermission() async {
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      hasPermission.value =
          settings.authorizationStatus == AuthorizationStatus.authorized;
    } catch (_) {}
  }

  Future<void> _getFCMToken() async {
    try {
      final token = await _fcm.getToken();
      if (token != null) {
        final userId = _getUserId();
        if (userId != null) {
          await _db.collection('userProfiles').doc(userId).update({
            'fcmToken': token,
            'lastActive': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (_) {}
  }

  void _setupListeners() {
    _fcm.onTokenRefresh.listen((token) async {
      final userId = _getUserId();
      if (userId != null) {
        await _db.collection('userProfiles').doc(userId).update({
          'fcmToken': token,
        });
      }
    });

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;
    final isMandatory = data['isMandatory'] == 'true';
    final surveyId = data['surveyId'] as String?;

    if (type == 'survey' && surveyId != null) {
      if (isMandatory) {
        Get.to(() => SurveyPage(surveyId: surveyId));
      } else {
        await _showLocalNotification(message);
      }
    } else {
      final notification = message.notification;
      if (notification != null) {
        await _showLocalNotification(message);
      }
    }
  }

  Future<void> _handleNotificationTap(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'] as String?;
    final surveyId = data['surveyId'] as String?;

    Get.find<AnalyticsService>().trackNotificationClicked(
      type ?? 'unknown',
      surveyId: surveyId,
    );

    _navigateByType(data);
  }

  void _navigateByType(Map<String, dynamic> data) {
    final type = data['type'] as String?;
    final surveyId = data['surveyId'] as String?;

    if (type == 'survey') {
      Get.offAll(() => SurveyPage(surveyId: surveyId));
      return;
    }

    switch (type) {
      case 'notification':
        Get.to(() => const MainPage());
        break;
      case 'line':
        Get.offAll(() => const MainPage());
        break;
      default:
        Get.offAll(() => const MainPage());
        break;
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    final payload = jsonEncode(message.data);
    const androidDetails = AndroidNotificationDetails(
      'tobis_channel',
      'Tobis Notifications',
      channelDescription: 'Tobis app notifications',
      icon: '@mipmap/ic_launcher',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      details,
      payload: payload,
    );
  }

  void _initLocalNotifications() {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);
    _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        try {
          final payload = response.payload;
          if (payload != null) {
            final data = jsonDecode(payload) as Map<String, dynamic>;
            _navigateByType(data);
          }
        } catch (_) {}
      },
    );
  }

  Future<void> subscribeToTopic(String topic) async {
    await _fcm.subscribeToTopic(topic);
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    await _fcm.unsubscribeFromTopic(topic);
  }

  Future<void> syncSubscriptions(Map<String, dynamic> profile) async {
    await subscribeToTopic('all');

    final currentCity = profile['city'] as String?;
    if (currentCity != null && currentCity.isNotEmpty) {
      await subscribeToTopic('city_$currentCity');
    }

    final favoriteLines = profile['favoriteLines'] as List<dynamic>?;
    if (favoriteLines != null) {
      for (final line in favoriteLines) {
        await subscribeToTopic('line_$line');
      }
    }

    final category = profile['category'] as String?;
    if (category != null && category.isNotEmpty) {
      await subscribeToTopic('category_$category');
    }
  }

  String? _getUserId() {
    try {
      return AuthService.to.firebaseUser?.uid;
    } catch (_) {
      return null;
    }
  }
}
