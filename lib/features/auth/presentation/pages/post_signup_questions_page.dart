import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/features/auth/services/onboarding_service.dart';
import 'package:bus_app/features/home/presentation/pages/main_page.dart';

class PostSignupQuestionsPage extends StatefulWidget {
  const PostSignupQuestionsPage({super.key});

  @override
  State<PostSignupQuestionsPage> createState() => _PostSignupQuestionsPageState();
}

class _PostSignupQuestionsPageState extends State<PostSignupQuestionsPage> {
  final _service = Get.find<OnboardingService>();
  final _pageController = PageController();
  int _currentStep = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_currentStep < _steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubicEmphasized,
      );
      setState(() => _currentStep++);
    } else {
      _submit();
    }
  }

  void _previous() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubicEmphasized,
      );
      setState(() => _currentStep--);
    }
  }

  void _submit() async {
    await _service.submitOnboarding();
    if (mounted) Get.offAll(() => const MainPage());
  }

  bool get _canProceed {
    switch (_currentStep) {
      case 0: return _service.gender.isNotEmpty;
      case 1: return _service.age > 0;
      case 2: return _service.cityController.text.trim().isNotEmpty || _service.city.isNotEmpty;
      case 3: return _service.status.isNotEmpty;
      case 4: return _service.mainLineController.text.trim().isNotEmpty || _service.mainLine.isNotEmpty;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Get.locale?.languageCode == 'ar';
    final font = isArabic ? GoogleFonts.ibmPlexSansArabic().fontFamily : null;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_currentStep > 0) {
          _previous();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentStep > 0
              ? IconButton(
                  icon: Icon(Icons.arrow_back_rounded, color: Colors.grey[600]),
                  onPressed: _previous,
                )
              : null,
        ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Text(
                    '${_currentStep + 1} / ${_steps.length}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryBlue,
                      fontFamily: font,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentStep + 1) / _steps.length,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _steps.length,
                onPageChanged: (i) => setState(() => _currentStep = i),
                itemBuilder: (context, index) {
                  return _QuestionCard(
                    step: _steps[index],
                    service: _service,
                    isArabic: isArabic,
                    font: font,
                    onChanged: () => setState(() {}),
                  );
                },
              ),
            ),
            _buildBottomNav(isArabic, font),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildBottomNav(bool isArabic, String? font) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _canProceed ? _next : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: Colors.grey[200],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: Text(
            _currentStep < _steps.length - 1
                ? (isArabic ? 'متابعة' : 'Continue')
                : (isArabic ? 'إكمال' : 'Complete'),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

final _steps = <QuestionStep>[
  QuestionStep(
    icon: Icons.wc_rounded,
    title: 'What is your gender?',
    titleAr: 'ما هو جنسك؟',
    subtitle: 'This helps us understand our user demographics',
    subtitleAr: 'هذا يساعدنا في فهم الفئات السكانية للمستخدمين',
    type: QuestionType.gender,
  ),
  QuestionStep(
    icon: Icons.cake_rounded,
    title: 'How old are you?',
    titleAr: 'كم عمرك؟',
    subtitle: 'Select your age range',
    subtitleAr: 'اختر فئتك العمرية',
    type: QuestionType.age,
  ),
  QuestionStep(
    icon: Icons.location_city_rounded,
    title: 'Which city do you live in?',
    titleAr: 'في أي مدينة تسكن؟',
    subtitle: 'We use this to show relevant bus lines',
    subtitleAr: 'نستخدم هذا لعرض خطوط الحافلات المناسبة',
    type: QuestionType.city,
  ),
  QuestionStep(
    icon: Icons.business_center_rounded,
    title: 'What is your professional status?',
    titleAr: 'ما هي حالتك المهنية؟',
    subtitle: 'Select your current occupation',
    subtitleAr: 'اختر مهنتك الحالية',
    type: QuestionType.status,
  ),
  QuestionStep(
    icon: Icons.route_rounded,
    title: 'What is your main bus line?',
    titleAr: 'ما هو خط الحافلات الرئيسي الخاص بك؟',
    subtitle: 'The bus route you use most often',
    subtitleAr: 'خط الحافلات الذي تستخدمه أكثر من غيره',
    type: QuestionType.busLine,
  ),
];

class _QuestionCard extends StatelessWidget {
  final QuestionStep step;
  final OnboardingService service;
  final bool isArabic;
  final String? font;
  final VoidCallback onChanged;

  const _QuestionCard({
    required this.step,
    required this.service,
    required this.isArabic,
    required this.font,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(step.icon, color: AppTheme.primaryBlue, size: 28),
          ),
          const SizedBox(height: 24),
          Text(
            isArabic ? step.titleAr : step.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontFamily: font,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isArabic ? step.subtitleAr : step.subtitle,
            style: TextStyle(fontSize: 15, color: Colors.grey[500], fontFamily: font),
          ),
          const SizedBox(height: 32),
          Expanded(child: _buildInput()),
        ],
      ),
    );
  }

  Widget _buildInput() {
    switch (step.type) {
      case QuestionType.gender:
        return _buildChipGroup(
          options: isArabic
              ? ['رجل', 'امرأة']
              : ['Man', 'Woman'],
          selected: service.gender,
          onSelect: (v) {
            service.gender = v;
            onChanged();
          },
        );
      case QuestionType.age:
        final ages = ['18-24', '25-34', '35-44', '45-54', '55+'];
        return _buildChipGroup(
          options: ages,
          selected: service.age > 0
              ? ages.firstWhere(
                  (a) => a.replaceAll('+', '').startsWith(service.age.toString()),
                  orElse: () => '',
                )
              : '',
          onSelect: (v) {
            final cleanStr = v.replaceAll('+', '').split('-').first;
            service.age = int.tryParse(cleanStr) ?? 18;
            onChanged();
          },
        );
      case QuestionType.city:
        return _buildTextField(
          controller: service.cityController,
          hint: isArabic ? 'مثال: الدار البيضاء' : 'e.g. Casablanca',
          onChanged: (v) => onChanged(),
        );
      case QuestionType.status:
        return _buildChipGroup(
          options: isArabic
              ? ['طالب', 'موظف', 'عامل', 'عمل جزئي', 'بدون عمل']
              : ['Student', 'Employee', 'Worker', 'Part-time', 'Unemployed'],
          selected: service.status,
          onSelect: (v) {
            service.status = v;
            onChanged();
          },
        );
      case QuestionType.busLine:
        return _buildTextField(
          controller: service.mainLineController,
          hint: isArabic ? 'مثال: الخط 30' : 'e.g. Line 30',
          onChanged: (v) => onChanged(),
        );
    }
  }

  Widget _buildChipGroup({
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: options.map((option) {
        final isSelected = option == selected;
        return Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => onSelect(option),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : Colors.grey[200]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.primaryBlue : Colors.grey[700],
                  fontFamily: font,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required ValueChanged<String> onChanged,
  }) {
    return TextField(
      controller: controller,
      style: TextStyle(fontFamily: font),
      decoration: InputDecoration(
        hintText: hint,
      ),
      onChanged: onChanged,
    );
  }
}

enum QuestionType { gender, age, city, status, busLine }

class QuestionStep {
  final IconData icon;
  final String title;
  final String titleAr;
  final String subtitle;
  final String subtitleAr;
  final QuestionType type;

  QuestionStep({
    required this.icon,
    required this.title,
    required this.titleAr,
    required this.subtitle,
    required this.subtitleAr,
    required this.type,
  });
}
