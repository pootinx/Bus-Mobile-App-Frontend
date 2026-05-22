import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'package:bus_app/features/auth/models/user_model.dart';

class ProfileService extends GetxService {
  static ProfileService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final Rx<UserModel?> _userModel = Rx<UserModel?>(null);

  UserModel? get user => _userModel.value;

  Future<UserModel?> fetchUserProfile(User firebaseUser) async {
    try {
      final doc = await _db.collection('userProfiles').doc(firebaseUser.uid).get();
      if (doc.exists) {
        final model = UserModel.fromFirestore(doc);
        _userModel.value = model;
        return model;
      }
      return null;
    } catch (e) {
      debugPrint("Error fetching user profile: $e");
      return null;
    }
  }

  Future<void> createUserProfile(User firebaseUser, String fullName) async {
    final newUser = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      fullName: fullName,
    );
    try {
      await _db.collection('userProfiles').doc(firebaseUser.uid).set({
        ...newUser.toFirestore(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      _userModel.value = newUser;
    } catch (e) {
      debugPrint("Error creating user profile: $e");
    }
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    final userId = _userModel.value?.id;
    if (userId == null) return;

    try {
      await _db.collection('userProfiles').doc(userId).update({
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      // Refresh local model
      final doc = await _db.collection('userProfiles').doc(userId).get();
      if (doc.exists) {
        _userModel.value = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint("Error updating profile: $e");
    }
  }

  void clearUserProfile() {
    _userModel.value = null;
  }
}
