import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';

class AuthService extends GetxService {
  static AuthService get to => Get.find();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final Rx<User?> _firebaseUser;
  Timer? _emailVerificationTimer;

  final RxBool isLoading = false.obs;
  final RxBool isVerified = false.obs;

  User? get firebaseUser => _firebaseUser.value;
  Rx<User?> get firebaseUserObs => _firebaseUser;

  @override
  void onInit() {
    super.onInit();
    _firebaseUser = Rx<User?>(_auth.currentUser);
    isVerified.value = _auth.currentUser?.emailVerified ?? false;
    _firebaseUser.bindStream(_auth.userChanges());
    ever(_firebaseUser, _onUserChanged);
  }

  @override
  void onClose() {
    _emailVerificationTimer?.cancel();
    super.onClose();
  }

  void _onUserChanged(User? user) {
    if (user != null) {
      isVerified.value = user.emailVerified;
      if (user.emailVerified) {
        _emailVerificationTimer?.cancel();
      }
    } else {
      isVerified.value = false;
      ProfileService.to.clearUserProfile();
    }
  }

  Future<void> createUserWithEmailAndPassword(String email, String password, String fullName) async {
    try {
      isLoading.value = true;
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        await ProfileService.to.createUserProfile(userCredential.user!, fullName);
        await sendVerificationEmail();
      }
    } on FirebaseAuthException catch (e) {
      _showError(e);
    } catch (e) {
      _showError(null, fallback: 'An unexpected error occurred.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      isLoading.value = true;
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      _showError(e, isLogin: true);
    } catch (e) {
      _showError(null, fallback: 'An unexpected error occurred.');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    _emailVerificationTimer?.cancel();
    await _auth.signOut();
    ProfileService.to.clearUserProfile();
  }

  void startEmailVerificationTimer() {
    _emailVerificationTimer?.cancel();
    _emailVerificationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _auth.currentUser?.reload();
      final user = _auth.currentUser;
      if (user != null && user.emailVerified) {
        _emailVerificationTimer?.cancel();
        isVerified.value = true;
      }
    });
  }

  Future<void> manuallyCheckEmailVerificationStatus() async {
    await _auth.currentUser?.reload();
    final user = _auth.currentUser;
    if (user != null) {
      isVerified.value = user.emailVerified;
    }
  }

  Future<void> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      startEmailVerificationTimer();
      Get.snackbar(
        'Email Sent',
        'A verification email has been sent to your address.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message ?? 'Could not send verification email.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      Get.snackbar(
        'Email Sent',
        'A password reset email has been sent.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green.withOpacity(0.8),
        colorText: Colors.white,
      );
    } on FirebaseAuthException catch (e) {
      Get.snackbar(
        'Error',
        e.message ?? 'Could not send reset email.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red.withOpacity(0.8),
        colorText: Colors.white,
      );
    }
  }

  void _showError(FirebaseAuthException? e, {bool isLogin = false, String? fallback}) {
    String message;
    if (e != null) {
      switch (e.code) {
        case 'email-already-in-use':
          message = 'Cet e-mail est déjà utilisé.';
          break;
        case 'weak-password':
          message = 'Le mot de passe est trop court.';
          break;
        case 'invalid-email':
          message = "L'adresse e-mail n'est pas valide.";
          break;
        case 'user-not-found':
        case 'wrong-password':
          message = 'E-mail ou mot de passe incorrect.';
          break;
        case 'too-many-requests':
          message = 'Trop de tentatives. Réessayez plus tard.';
          break;
        default:
          message = e.message ?? fallback ?? 'Une erreur est survenue.';
      }
    } else {
      message = fallback ?? 'Une erreur est survenue.';
    }

    Get.snackbar(
      isLogin ? 'Erreur de connexion' : "Erreur d'inscription",
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.red.withOpacity(0.8),
      colorText: Colors.white,
      duration: const Duration(seconds: 4),
    );
  }
}
