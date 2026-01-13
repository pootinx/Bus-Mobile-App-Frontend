
import 'package:bus_app/features/authentication/screens/signup_screen/signup_screen.dart';
import 'package:bus_app/features/authentication/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final RxBool obscureText = true.obs;

    return Scaffold(
      backgroundColor: const Color(0xFF005C97),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 100, left: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Hello.",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                  Text("Welcome back!",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 20),
                    const Text("Enter to your account",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 30),
                    TextFormField(
                      controller: emailController,
                      decoration: const InputDecoration(
                        labelText: "E-mail",
                        border: UnderlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 20),
                    Obx(() => TextFormField(
                          controller: passwordController,
                          obscureText: obscureText.value,
                          decoration: InputDecoration(
                            labelText: "Password",
                            border: const UnderlineInputBorder(),
                            suffixIcon: IconButton(
                              icon: Icon(obscureText.value
                                  ? Icons.visibility_off
                                  : Icons.visibility),
                              onPressed: () {
                                obscureText.value = !obscureText.value;
                              },
                            ),
                          ),
                        )),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password
                        },
                        child: const Text("Forgot the password?",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // The AuthService now handles all errors internally.
                          // No need for a try-catch block here.
                          AuthService.to.signInWithEmailAndPassword(
                            emailController.text.trim(),
                            passwordController.text.trim(),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005C97),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                        child: const Text("Login",
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () {
                            Get.to(() => const SignupScreen());
                          },
                          child: const Text("Sign up",
                              style: TextStyle(
                                  color: Color(0xFF005C97),
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
