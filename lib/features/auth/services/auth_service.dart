
import 'dart:async';

import 'package:bus_app/features/auth/presentation/pages/login_screen/login_screen.dart';
import 'package:bus_app/features/auth/presentation/pages/verify_email_screen.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'profile_service.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final Rx<User?> _firebaseUser;
  Timer? _emailVerificationTimer;

  // Track authentication progress
  final RxBool isLoading = false.obs;

  User? get firebaseUser => _firebaseUser.value;

  @override
  void onReady() {
    _firebaseUser = Rx<User?>(_auth.currentUser);
    _firebaseUser.bindStream(_auth.userChanges());
    // The `ever` listener is the core of the app's routing.
    // It reacts to any change in the user's authentication state.
    ever(_firebaseUser, _setInitialScreen);
  }

  @override
  void onClose() {
    // Stop the timer when the service is closed to prevent memory leaks.
    _emailVerificationTimer?.cancel();
    super.onClose();
  }

  // This function determines which screen to show based on the user's state.
  _setInitialScreen(User? user) async {
    // Cancel any existing timer when the user state changes.
    _emailVerificationTimer?.cancel();

    if (user != null) {
      // USER IS LOGGED IN
      await ProfileService.to.fetchUserProfile(user); // Fetch profile data

      if (user.emailVerified) {
        // If email is verified, go to the main app.
        Get.offAll(() => const MainPage());
      } else {
        // If email is NOT verified, go to the verification screen.
        Get.offAll(() => const VerifyEmailScreen());
        // And start a timer to automatically check for verification.
        _startEmailVerificationTimer();
      }
    } else {
      // USER IS LOGGED OUT
      // Clear any stale profile data and go to the login screen.
      ProfileService.to.clearUserProfile();
      Get.offAll(() => const LoginScreen());
    }
  }

  // --- Core Authentication Methods ---

  Future<void> createUserWithEmailAndPassword(String email, String password, String fullName) async {
    try {
      isLoading.value = true;
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (userCredential.user != null) {
        // Create the user profile in Firestore.
        await ProfileService.to.createUserProfile(userCredential.user!, fullName);
        // Send the verification email.
        await sendVerificationEmail();
        // The `_setInitialScreen` listener will automatically navigate to VerifyEmailScreen.
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Cet e-mail est déjà utilisé par un autre compte.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Le mot de passe est trop court.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'L\'adresse e-mail n\'est pas valide.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      Get.snackbar(
        'Erreur d\'inscription', 
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Erreur d\'inscription', 
        'Une erreur inattendue s\'est produite.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      // The `_setInitialScreen` listener will handle navigation based on verification status.
    } on FirebaseAuthException catch (e) {
      String errorMessage = 'An unknown error occurred.';
      if (e.code == 'user-not-found' || e.code == 'wrong-password') {
        errorMessage = 'E-mail ou mot de passe incorrect.';
      } else if (e.message != null) {
        errorMessage = e.message!;
      }
      
      Get.snackbar(
        'Erreur de connexion', 
        errorMessage,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
        duration: const Duration(seconds: 4),
      );
    } catch (e) {
      Get.snackbar(
        'Erreur de connexion', 
        'Une erreur inattendue s\'est produite.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    // The `_setInitialScreen` listener will handle navigation to the LoginScreen.
  }

  // --- Email Verification Methods ---

  // Starts a timer to periodically check if the user's email has been verified.
  void _startEmailVerificationTimer() {
    _emailVerificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      await _firebaseUser.value?.reload();
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        timer.cancel();
        // User is now verified, navigate to the main screen.
        Get.offAll(() => const MainPage());
      }
    });
  }

  // Manually reloads the user to check their verification status.
  Future<void> manuallyCheckEmailVerificationStatus() async {
    await _firebaseUser.value?.reload();
    // The `ever` listener on _firebaseUser will automatically trigger
    // `_setInitialScreen` if the user's state (like emailVerified) changes.
  }

  // Sends a new verification email.
  Future<void> sendVerificationEmail() async {
    try {
      await _firebaseUser.value?.sendEmailVerification();
      Get.snackbar('Email Sent', 'A new verification email has been sent to your address.');
    } on FirebaseAuthException catch (e) {
      // Handle errors like 'too-many-requests'.
      Get.snackbar('Error', e.message ?? 'Could not send verification email.');
    } catch (e) {
      Get.snackbar('Error', 'An unexpected error occurred.');
    }
  }

  // Sends a password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar('Email Sent', 'A password reset email has been sent to your address.');
    } on FirebaseAuthException catch (e) {
      Get.snackbar('Error', e.message ?? 'Could not send reset email.');
    } catch (e) {
      Get.snackbar('Error', 'An unexpected error occurred.');
    }
  }
}
