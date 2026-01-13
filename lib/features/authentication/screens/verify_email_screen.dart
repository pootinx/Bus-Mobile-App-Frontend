
import 'package:bus_app/features/authentication/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class VerifyEmailScreen extends StatelessWidget {
  const VerifyEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF005C97),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.email_outlined, color: Colors.white, size: 100),
            const SizedBox(height: 30),
            const Text(
              "Verify your email address",
              style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              // Display the user's email, safely handling the case where it might be null.
              "We have sent a verification email to ${AuthService.to.firebaseUser?.email ?? 'your email'}. Please check your inbox and click the link to activate your account.",
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // The user can manually trigger a check.
                  // The listener in AuthService will automatically navigate them if they are verified.
                  AuthService.to.manuallyCheckEmailVerificationStatus();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text("I have verified, continue", style: TextStyle(color: Color(0xFF005C97))),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                AuthService.to.sendVerificationEmail();
              },
              child: const Text("Resend verification email", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                AuthService.to.signOut();
              },
              child: const Text("Sign out", style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }
}
