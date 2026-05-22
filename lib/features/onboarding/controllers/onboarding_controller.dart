import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bus_app/features/onboarding/models/onboarding_models.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';

class OnboardingController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final pageController = PageController();
  final currentStep = 0.obs;
  final data = OnboardingData();
  final isLoading = false.obs;

  final totalSteps = 4;

  String? selectedGender;
  String? selectedStatus;
  String? selectedPayment;
  bool ticketIssuesValue = false;

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final ageController = TextEditingController();
  final cityController = TextEditingController();
  final mainLineController = TextEditingController();
  final secondaryLineController = TextEditingController();
  final otherLineController = TextEditingController();
  final stationController = TextEditingController();
  final waitingTimeController = TextEditingController();
  final travelTimeController = TextEditingController();
  final usageTimeController = TextEditingController();

  @override
  void onClose() {
    pageController.dispose();
    nameController.dispose();
    phoneController.dispose();
    ageController.dispose();
    cityController.dispose();
    mainLineController.dispose();
    secondaryLineController.dispose();
    otherLineController.dispose();
    stationController.dispose();
    waitingTimeController.dispose();
    travelTimeController.dispose();
    usageTimeController.dispose();
    super.onClose();
  }

  void nextStep() {
    if (currentStep.value < totalSteps - 1) {
      pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      currentStep.value++;
    }
  }

  void previousStep() {
    if (currentStep.value > 0) {
      pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
      currentStep.value--;
    }
  }

  void collectProfileData() {
    data.fullName = nameController.text.trim();
    data.phone = phoneController.text.trim();
    data.gender = selectedGender ?? '';
    data.age = int.tryParse(ageController.text) ?? 0;
    data.professionalStatus = selectedStatus ?? '';
    data.city = cityController.text.trim();
  }

  void collectTransportData() {
    data.mainLine = mainLineController.text.trim();
    data.secondaryLine = secondaryLineController.text.trim();
    data.otherLine = otherLineController.text.trim();
    data.boardingStation = stationController.text.trim();
    data.waitingTime = waitingTimeController.text.trim();
    data.travelTime = travelTimeController.text.trim();
    data.usageTime = usageTimeController.text.trim();
    data.ticketIssues = ticketIssuesValue;
    data.paymentMethod = selectedPayment ?? '';
  }

  Future<void> submitOnboarding() async {
    try {
      isLoading.value = true;
      collectProfileData();
      collectTransportData();

      final userId = AuthService.to.firebaseUser?.uid;
      if (userId == null) return;

      final profileMap = data.toProfileMap();
      profileMap['updatedAt'] = FieldValue.serverTimestamp();
      profileMap['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('userProfiles').doc(userId).set(profileMap, SetOptions(merge: true));

      final transportMap = data.toTransportHabitsMap();
      transportMap['createdAt'] = FieldValue.serverTimestamp();
      await _db.collection('transportHabits').doc(userId).set(transportMap);

      await _db.collection('analyticsEvents').add({
        'userId': userId,
        'eventType': 'onboarding_completed',
        'data': {'age': data.age, 'city': data.city, 'status': data.professionalStatus},
        'timestamp': FieldValue.serverTimestamp(),
      });

      Get.offAll(() => const MainPage());
    } catch (e) {
      Get.snackbar('Error', 'Failed to save profile: $e');
    } finally {
      isLoading.value = false;
    }
  }
}
