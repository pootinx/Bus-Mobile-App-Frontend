import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final font = isArabic ? GoogleFonts.ibmPlexSansArabic().fontFamily : null;
    final email = AuthService.to.firebaseUser?.email ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.email_outlined,
                    color: AppTheme.primaryBlue,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              Text(
                isArabic ? 'تحقق من بريدك الإلكتروني' : 'Check your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontFamily: font,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                isArabic
                    ? 'لقد أرسلنا رابط التحقق إلى\n$email'
                    : 'We sent a verification link to\n$email',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[500],
                  height: 1.5,
                  fontFamily: font,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    AuthService.to.manuallyCheckEmailVerificationStatus();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isArabic ? 'تم التحقق، متابعة' : 'I\'ve verified, continue',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => AuthService.to.sendVerificationEmail(),
                child: Text(
                  isArabic ? 'إعادة إرسال البريد' : 'Resend email',
                  style: TextStyle(color: AppTheme.primaryBlue, fontFamily: font),
                ),
              ),
              TextButton(
                onPressed: () => AuthService.to.signOut(),
                child: Text(
                  isArabic ? 'تسجيل الخروج' : 'Sign out',
                  style: TextStyle(color: Colors.grey[400], fontFamily: font),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
