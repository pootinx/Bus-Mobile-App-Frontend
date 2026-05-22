import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bus_app/core/theme/app_theme.dart';

class FirstLaunchOnboardingPage extends StatefulWidget {
  const FirstLaunchOnboardingPage({super.key});

  @override
  State<FirstLaunchOnboardingPage> createState() => _FirstLaunchOnboardingPageState();
}

class _FirstLaunchOnboardingPageState extends State<FirstLaunchOnboardingPage> {
  final _pageController = PageController();
  int _currentPage = 0;

  final _pages = <_OnboardingItem>[
    _OnboardingItem(
      icon: Icons.directions_bus_rounded,
      title: 'Smart Bus Tracking',
      titleAr: 'تتبع الحافلات الذكي',
      subtitle: 'Real-time bus locations and arrivals at your fingertips',
      subtitleAr: 'مواقع الحافلات وأوقات الوصول في الوقت الفعلي بين يديك',
      color: AppTheme.primaryBlue,
    ),
    _OnboardingItem(
      icon: Icons.poll_rounded,
      title: 'Voice Your Opinion',
      titleAr: 'أعرب عن رأيك',
      subtitle: 'Participate in surveys and help improve public transport',
      subtitleAr: 'شارك في الاستبيانات وساعد في تحسين النقل العام',
      color: AppTheme.accentOrange,
    ),
    _OnboardingItem(
      icon: Icons.notifications_active_rounded,
      title: 'Stay Informed',
      titleAr: 'ابق على اطلاع',
      subtitle: 'Get instant alerts about routes, delays, and updates',
      subtitleAr: 'احصل على تنبيهات فورية حول المسارات والتأخيرات والتحديثات',
      color: AppTheme.primaryBlue,
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            if (_currentPage < _pages.length - 1)
              Align(
                alignment: Alignment.topRight,
                child: TextButton(
                  onPressed: () => _pageController.animateToPage(
                    _pages.length - 1,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  ),
                  child: Text(
                    isArabic ? 'تخطي' : 'Skip',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                ),
              ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  final page = _pages[index];
                  return AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      final pageOffset = _pageController.page ?? index.toDouble();
                      final relativeIndex = index - pageOffset;
                      final opacity = 1.0 - (relativeIndex.abs()).clamp(0.0, 1.0);
                      final translateY = 30.0 * (relativeIndex.abs()).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: opacity,
                        child: Transform.translate(
                          offset: Offset(0, translateY),
                          child: child,
                        ),
                      );
                    },
                    child: _buildPageContent(page, isArabic),
                  );
                },
              ),
            ),
            _buildBottomSection(isArabic),
          ],
        ),
      ),
    );
  }

  Widget _buildPageContent(_OnboardingItem page, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: 48),
          Text(
            isArabic ? page.titleAr : page.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: isArabic ? GoogleFonts.ibmPlexSansArabic().fontFamily : null,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isArabic ? page.subtitleAr : page.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
              height: 1.5,
              fontFamily: isArabic ? GoogleFonts.ibmPlexSansArabic().fontFamily : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(bool isArabic) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
      child: Column(
        children: [
          _buildDots(isArabic),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pages.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                  );
                } else {
                  Get.back(result: true);
                }
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
                _currentPage < _pages.length - 1
                    ? (isArabic ? 'متابعة' : 'Continue')
                    : (isArabic ? 'ابدأ الآن' : 'Get Started'),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDots(bool isArabic) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_pages.length, (i) {
        final isActive = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryBlue : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

class _OnboardingItem {
  final IconData icon;
  final String title;
  final String titleAr;
  final String subtitle;
  final String subtitleAr;
  final Color color;

  _OnboardingItem({
    required this.icon,
    required this.title,
    required this.titleAr,
    required this.subtitle,
    required this.subtitleAr,
    required this.color,
  });
}
