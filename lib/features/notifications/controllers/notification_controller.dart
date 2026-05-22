import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/notifications/models/notification_model.dart';
import 'package:bus_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:bus_app/features/surveys/presentation/pages/survey_page.dart';
import 'package:bus_app/features/surveys/services/survey_service.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';
import 'package:bus_app/features/analytics/services/analytics_service.dart';

class NotificationController extends GetxController {
  static NotificationController get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final RxList<AppNotification> notifications = <AppNotification>[].obs;
  final RxInt unreadCount = 0.obs;
  final RxBool isLoading = false.obs;

  StreamSubscription? _subscription;

  List<AppNotification> get popupNotifications {
    if (notifications.length <= 5) return notifications;
    return notifications.sublist(0, 5);
  }

  @override
  void onInit() {
    super.onInit();
    ever(AuthService.to.firebaseUserObs, (_) {
      final user = AuthService.to.firebaseUser;
      if (user != null) {
        startListening();
      } else {
        stopListening();
        notifications.clear();
        unreadCount.value = 0;
      }
    });
  }

  @override
  void onClose() {
    _subscription?.cancel();
    super.onClose();
  }

  void startListening() {
    final userId = _getUserId();
    if (userId == null) return;

    _subscription?.cancel();
    isLoading.value = true;

    _subscription = _db
        .collection('inAppNotifications')
        .where('uid', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen((snapshot) {
      final list = snapshot.docs.map((doc) {
        return AppNotification.fromFirestore(doc);
      }).toList();

      notifications.value = list;
      unreadCount.value = list.where((n) => !n.isRead).length;
      isLoading.value = false;
    }, onError: (_) {
      isLoading.value = false;
    });
  }

  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  Future<void> markAsRead(String notificationId) async {
    final userId = _getUserId();
    if (userId == null) return;
    try {
      await _db
          .collection('inAppNotifications')
          .doc(notificationId)
          .update({'read': true, 'isRead': true});
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final userId = _getUserId();
    if (userId == null) return;

    final unreadIds = notifications
        .where((n) => !n.isRead)
        .map((n) => n.id)
        .toList();

    if (unreadIds.isEmpty) return;

    final batch = _db.batch();
    final ref = _db.collection('inAppNotifications');

    for (final id in unreadIds) {
      batch.update(ref.doc(id), {'read': true, 'isRead': true});
    }

    try {
      await batch.commit();
    } catch (_) {}
  }

  void navigateToNotification(AppNotification notification) {
    Get.find<AnalyticsService>().trackNotificationClicked(
      notification.type.name,
      surveyId: notification.surveyId,
    );

    if (!notification.isRead) {
      markAsRead(notification.id);
    }

    if (notification.surveyId != null) {
      Get.find<SurveyService>().markNotificationOpened(notification.surveyId!);
    }

    _handleNavigation(notification);
  }

  void navigateToDeepLink(String deepLink) {
    if (deepLink.startsWith('/survey/') || deepLink.startsWith('survey://')) {
      final surveyId = deepLink.split('/').last;
      Get.to(() => SurveyPage(surveyId: surveyId));
    } else {
      Get.to(() => const MainPage());
    }
  }

  void navigateToFullList() {
    Get.to(
      () => const NotificationsPage(),
      transition: Transition.downToUp,
      duration: const Duration(milliseconds: 300),
    );
  }

  void _handleNavigation(AppNotification notification) {
    if (notification.deepLink != null && notification.deepLink!.isNotEmpty) {
      navigateToDeepLink(notification.deepLink!);
      return;
    }

    switch (notification.type) {
      case NotificationType.survey:
        Get.to(() => SurveyPage(surveyId: notification.surveyId));
      case NotificationType.system:
      case NotificationType.alert:
      case NotificationType.line:
      case NotificationType.notification:
        Get.to(() => const MainPage());
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
