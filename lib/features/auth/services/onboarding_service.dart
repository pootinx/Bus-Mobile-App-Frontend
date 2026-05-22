import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';

class OnboardingService extends GetxService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  String gender = '';
  int age = 0;
  String city = '';
  String status = '';
  String mainLine = '';

  final cityController = TextEditingController();
  final mainLineController = TextEditingController();

  @override
  void onClose() {
    cityController.dispose();
    mainLineController.dispose();
    super.onClose();
  }

  Future<void> submitOnboarding() async {
    final userId = AuthService.to.firebaseUser?.uid;
    if (userId == null) return;

    final data = <String, dynamic>{
      'gender': gender,
      'age': age,
      'city': cityController.text.isNotEmpty ? cityController.text : city,
      'professionalStatus': status,
      'mainLine': mainLineController.text.isNotEmpty ? mainLineController.text : mainLine,
      'onboardingCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _db.collection('userProfiles').doc(userId).set(data, SetOptions(merge: true));

    await _db.collection('analyticsEvents').add({
      'userId': userId,
      'eventType': 'onboarding_completed',
      'data': {'age': age, 'city': city},
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
