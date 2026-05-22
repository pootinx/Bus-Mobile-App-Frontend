import 'package:cloud_firestore/cloud_firestore.dart';

class SurveyQuestion {
  final String id;
  final Map<String, String> questionText;
  final String type;
  final List<String> options;
  final bool isActive;
  final bool isMandatory;
  final int order;
  final num min;
  final num max;
  final List<String> aiTags;
  final String analyticsCategory;
  final bool reusable;

  SurveyQuestion({
    required this.id,
    required this.questionText,
    required this.type,
    this.options = const [],
    this.isActive = true,
    this.isMandatory = false,
    this.order = 0,
    this.min = 0,
    this.max = 100,
    this.aiTags = const [],
    this.analyticsCategory = 'general',
    this.reusable = true,
  });

  factory SurveyQuestion.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SurveyQuestion(
      id: doc.id,
      questionText: Map<String, String>.from(data['questionText'] ?? {}),
      type: data['type'] ?? 'text',
      options: List<String>.from(data['options'] ?? []),
      isActive: data['isActive'] ?? true,
      isMandatory: data['isMandatory'] ?? false,
      order: data['order'] ?? 0,
      min: data['min'] ?? 0,
      max: data['max'] ?? 100,
      aiTags: List<String>.from(data['aiTags'] ?? []),
      analyticsCategory: data['analyticsCategory'] ?? 'general',
      reusable: data['reusable'] ?? true,
    );
  }

  String getLocalizedText(String locale) {
    return questionText[locale] ?? questionText['en'] ?? '';
  }
}

class SurveyCampaign {
  final String id;
  final String name;
  final Map<String, String> title;
  final Map<String, String> description;
  final List<String> questionIds;
  final bool isActive;
  final bool isMandatory;
  final DateTime? expiresAt;
  final String targetAudience;
  final String targetValue;
  final String? city;
  final DateTime createdAt;
  final String createdBy;

  SurveyCampaign({
    required this.id,
    required this.name,
    this.title = const {},
    this.description = const {},
    required this.questionIds,
    this.isActive = true,
    this.isMandatory = false,
    this.expiresAt,
    this.targetAudience = 'all',
    this.targetValue = '',
    this.city,
    required this.createdAt,
    this.createdBy = '',
  });

  factory SurveyCampaign.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    Timestamp? expiresTs = data['expiresAt'] as Timestamp?;
    Timestamp? createdTs = data['createdAt'] as Timestamp?;
    return SurveyCampaign(
      id: doc.id,
      name: data['name'] ?? '',
      title: Map<String, String>.from(data['title'] ?? {}),
      description: Map<String, String>.from(data['description'] ?? {}),
      questionIds: List<String>.from(data['questionIds'] ?? []),
      isActive: data['isActive'] ?? true,
      isMandatory: data['isMandatory'] ?? false,
      expiresAt: expiresTs?.toDate(),
      targetAudience: data['targetAudience'] ?? 'all',
      targetValue: data['targetValue'] ?? '',
      city: data['city'] as String?,
      createdAt: createdTs?.toDate() ?? DateTime.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  String getLocalizedTitle(String locale) {
    return title[locale] ?? title['en'] ?? name;
  }

  String getLocalizedDescription(String locale) {
    return description[locale] ?? description['en'] ?? '';
  }
}

class UserSurveyState {
  final String id;
  final String uid;
  final String surveyId;
  final String status;
  final bool blocked;
  final bool isMandatory;
  final bool notificationSent;
  final bool notificationOpened;
  final DateTime? answeredAt;
  final DateTime? openedAt;
  final int reminderCount;
  final DateTime? expiresAt;
  final DateTime createdAt;

  UserSurveyState({
    required this.id,
    required this.uid,
    required this.surveyId,
    this.status = 'pending',
    this.blocked = false,
    this.isMandatory = false,
    this.notificationSent = false,
    this.notificationOpened = false,
    this.answeredAt,
    this.openedAt,
    this.reminderCount = 0,
    this.expiresAt,
    required this.createdAt,
  });

  factory UserSurveyState.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserSurveyState(
      id: doc.id,
      uid: data['uid'] ?? '',
      surveyId: data['surveyId'] ?? '',
      status: data['status'] ?? 'pending',
      blocked: data['blocked'] ?? false,
      isMandatory: data['isMandatory'] ?? false,
      notificationSent: data['notificationSent'] ?? false,
      notificationOpened: data['notificationOpened'] ?? false,
      answeredAt: (data['answeredAt'] as Timestamp?)?.toDate(),
      openedAt: (data['openedAt'] as Timestamp?)?.toDate(),
      reminderCount: data['reminderCount'] ?? 0,
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  bool get isPending => status == 'pending';
  bool get isAnswered => status == 'answered';
  bool get isExpired => status == 'expired';
}

class SurveyAnswer {
  final String id;
  final String uid;
  final String surveyId;
  final String questionId;
  final String answer;
  final dynamic answerValue;
  final String? city;
  final int? userAge;
  final String? userGender;
  final String? userStatus;
  final String? surveyName;
  final String? surveyType;
  final String? targetAudience;
  final DateTime? answeredAt;

  SurveyAnswer({
    required this.id,
    required this.uid,
    required this.surveyId,
    required this.questionId,
    required this.answer,
    this.answerValue,
    this.city,
    this.userAge,
    this.userGender,
    this.userStatus,
    this.surveyName,
    this.surveyType,
    this.targetAudience,
    this.answeredAt,
  });

  factory SurveyAnswer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final userMeta = data['userMetadata'] as Map<String, dynamic>?;
    return SurveyAnswer(
      id: doc.id,
      uid: data['uid'] ?? data['userId'] ?? '',
      surveyId: data['surveyId'] ?? '',
      questionId: data['questionId'] ?? '',
      answer: data['answer'] ?? '',
      answerValue: data['answerValue'],
      city: userMeta?['city'] as String? ?? data['city'] as String?,
      userAge: userMeta?['age'] as int? ?? data['userAge'] as int?,
      userGender: userMeta?['gender'] as String? ?? data['userGender'] as String?,
      userStatus: userMeta?['professionalStatus'] as String? ?? data['userStatus'] as String?,
      surveyName: data['surveyName'] as String?,
      surveyType: data['surveyType'] as String? ?? (data['isMandatory'] == true ? 'mandatory' : 'optional'),
      targetAudience: data['targetAudience'] as String?,
      answeredAt: (data['answeredAt'] as Timestamp?)?.toDate(),
    );
  }
}
