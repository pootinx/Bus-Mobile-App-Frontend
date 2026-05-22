import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String phone;
  final String gender;
  final int age;
  final String professionalStatus;
  final String city;
  final String mainLine;
  final String secondaryLine;
  final String boardingStation;
  final bool onboardingCompleted;
  final bool isBanned;
  final String? fcmToken;
  final DateTime? createdAt;
  final DateTime? lastActive;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone = '',
    this.gender = '',
    this.age = 0,
    this.professionalStatus = '',
    this.city = '',
    this.mainLine = '',
    this.secondaryLine = '',
    this.boardingStation = '',
    this.onboardingCompleted = false,
    this.isBanned = false,
    this.fcmToken,
    this.createdAt,
    this.lastActive,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      email: data['email'] ?? '',
      fullName: data['fullName'] ?? '',
      phone: data['phone'] ?? '',
      gender: data['gender'] ?? '',
      age: data['age'] ?? 0,
      professionalStatus: data['professionalStatus'] ?? '',
      city: data['city'] ?? '',
      mainLine: data['mainLine'] ?? '',
      secondaryLine: data['secondaryLine'] ?? '',
      boardingStation: data['boardingStation'] ?? '',
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      isBanned: data['isBanned'] ?? false,
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'fullName': fullName,
      'phone': phone,
      'gender': gender,
      'age': age,
      'professionalStatus': professionalStatus,
      'city': city,
      'mainLine': mainLine,
      'secondaryLine': secondaryLine,
      'boardingStation': boardingStation,
      'onboardingCompleted': onboardingCompleted,
      'isBanned': isBanned,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
