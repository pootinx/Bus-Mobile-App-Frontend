import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { survey, system, alert, line, notification }

class AppNotification {
  final String id;
  final String uid;
  final String? title;
  final String? body;
  final NotificationType type;
  final String? surveyId;
  final bool isRead;
  final bool isClicked;
  final String? deepLink;
  final String priority;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.uid,
    this.title,
    this.body,
    this.type = NotificationType.notification,
    this.surveyId,
    this.isRead = false,
    this.isClicked = false,
    this.deepLink,
    this.priority = 'normal',
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final titleRaw = data['title'];
    final bodyRaw = data['body'];
    final entityId = data['entityId'] as String?;
    final surveyId = data['surveyId'] as String? ?? entityId;

    return AppNotification(
      id: doc.id,
      uid: data['uid'] ?? '',
      title: _extractLocalized(titleRaw),
      body: _extractLocalized(bodyRaw),
      type: _parseType(data['type'] as String?),
      surveyId: surveyId,
      isRead: data['read'] == true || data['isRead'] == true,
      isClicked: data['clicked'] == true,
      deepLink: data['deepLink'] as String?,
      priority: data['priority'] as String? ?? 'normal',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  static String? _extractLocalized(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is Map) {
      return value['en'] as String? ?? value.values.first as String? ?? '';
    }
    return null;
  }

  static NotificationType _parseType(String? type) {
    switch (type) {
      case 'survey': return NotificationType.survey;
      case 'system': return NotificationType.system;
      case 'alert': return NotificationType.alert;
      case 'line': return NotificationType.line;
      default: return NotificationType.notification;
    }
  }
}
