
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';

import '../models/user_model.dart';

/// This service is responsible for all interactions with the user's profile data in Firestore.
/// It separates data management from authentication.
class ProfileService extends GetxService {
  static ProfileService get to => Get.find();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Observable user model
  final Rx<UserModel?> _userModel = Rx<UserModel?>(null);

  // Getter for the user model that other parts of the app can reactively listen to.
  UserModel? get user => _userModel.value;

  /// Fetches the user profile from Firestore and populates the user model.
  Future<void> fetchUserProfile(User firebaseUser) async {
    try {
      final doc = await _db.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists) {
        _userModel.value = UserModel.fromFirestore(doc);
      }
    } catch (e) {
      print("Error fetching user profile: $e");
      // Optionally, handle this error, e.g., by showing a snackbar.
    }
  }

  /// Creates a new user profile in Firestore after they sign up.
  Future<void> createUserProfile(User firebaseUser, String fullName) async {
    final newUser = UserModel(
      id: firebaseUser.uid,
      email: firebaseUser.email!,
      fullName: fullName,
    );
    try {
      await _db.collection('users').doc(firebaseUser.uid).set(newUser.toFirestore());
      _userModel.value = newUser;
    } catch (e) {
      print("Error creating user profile: $e");
      // Handle the error, maybe by deleting the Firebase user to allow a retry.
    }
  }

  /// Clears the user data on logout.
  void clearUserProfile() {
    _userModel.value = null;
  }
}
