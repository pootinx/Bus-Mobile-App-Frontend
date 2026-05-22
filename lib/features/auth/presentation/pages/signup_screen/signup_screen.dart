import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with SingleTickerProviderStateMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _obscureText = true.obs;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _nameController.dispose();
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[600]),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isArabic ? 'إنشاء حساب' : 'Create account',
                        style: TextStyle(
                          fontSize: 32, fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          fontFamily: font,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isArabic ? 'سجل للبدء في استخدام التطبيق' : 'Sign up to get started',
                        style: TextStyle(fontSize: 16, color: Colors.grey[500], fontFamily: font),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.12),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.2, 1, curve: Curves.easeOutCubic))),
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        style: TextStyle(fontFamily: font),
                        decoration: InputDecoration(
                          labelText: isArabic ? 'الاسم الكامل' : 'Full name',
                          prefixIcon: const Icon(Icons.person_outline, color: AppTheme.primaryBlue),
                        ),
                      ),
                      const SizedBox(height: 16),
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.15),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.4, 1, curve: Curves.easeOutCubic))),
                  child: Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Obx(() => ElevatedButton(
                          onPressed: AuthService.to.isLoading.value
                              ? null
                              : () {
                                  AuthService.to.createUserWithEmailAndPassword(
                                    _emailController.text.trim(),
                                    _passwordController.text.trim(),
                                    _nameController.text.trim(),
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
                                  isArabic ? 'إنشاء حساب' : 'Create Account',
                                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                                ),
                        )),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            isArabic ? 'لديك حساب بالفعل؟' : 'Already have an account?',
                            style: TextStyle(color: Colors.grey[500], fontFamily: font),
                          ),
                          TextButton(
                            onPressed: () => Get.back(),
                            child: Text(
                              isArabic ? 'تسجيل الدخول' : 'Sign In',
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
