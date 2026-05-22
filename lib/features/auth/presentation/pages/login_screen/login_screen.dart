import 'package:bus_app/features/auth/presentation/pages/signup_screen/signup_screen.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _obscureText = true.obs;
  late final AnimationController _animController;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnim = Tween<double>(begin: 0.1, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final font = isArabic ? GoogleFonts.ibmPlexSansArabic().fontFamily : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(_slideAnim),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.directions_bus_rounded,
                            color: AppTheme.primaryBlue, size: 28),
                      ),
                      const SizedBox(height: 32),
                      Text(
                        isArabic ? 'مرحباً بعودتك' : 'Welcome back',
                        style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: font,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'سجل الدخول للمتابعة' : 'Sign in to continue',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500], fontFamily: font),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 48),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic)),
                  ),
                  child: Form(
                    child: Column(
                      children: [
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: TextStyle(fontFamily: font),
                          decoration: InputDecoration(
                            labelText: isArabic ? 'البريد الإلكتروني' : 'Email',
                            prefixIcon: const Icon(Icons.email_outlined, color: AppTheme.primaryBlue),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Obx(() => TextField(
                          controller: _passwordController,
                          obscureText: _obscureText.value,
                          style: TextStyle(fontFamily: font),
                          decoration: InputDecoration(
                            labelText: isArabic ? 'كلمة المرور' : 'Password',
                            prefixIcon: const Icon(Icons.lock_outlined, color: AppTheme.primaryBlue),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscureText.value ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey,
                              ),
                              onPressed: () => _obscureText.value = !_obscureText.value,
                            ),
                          ),
                        )),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              final email = _emailController.text.trim();
                              if (email.isNotEmpty) {
                                AuthService.to.sendPasswordResetEmail(email);
                              }
                            },
                            child: Text(
                              isArabic ? 'نسيت كلمة المرور؟' : 'Forgot password?',
                              style: TextStyle(color: AppTheme.primaryBlue, fontFamily: font),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.1),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic)),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Obx(() => ElevatedButton(
                          onPressed: AuthService.to.isLoading.value
                              ? null
                              : () {
                                  AuthService.to.signInWithEmailAndPassword(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                  );
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: AuthService.to.isLoading.value
                              ? const SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2.5,
                                  ),
                                )
                              : Text(
                                  isArabic ? 'تسجيل الدخول' : 'Sign In',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                        )),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isArabic ? 'ليس لديك حساب؟' : "Don't have an account?",
                            style: TextStyle(color: Colors.grey[500], fontFamily: font),
                          ),
                          TextButton(
                            onPressed: () => Get.to(() => const SignupScreen(), transition: Transition.rightToLeft),
                            child: Text(
                              isArabic ? 'إنشاء حساب' : 'Sign Up',
                              style: TextStyle(
                                color: AppTheme.primaryBlue,
                                fontWeight: FontWeight.w600,
                                fontFamily: font,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
