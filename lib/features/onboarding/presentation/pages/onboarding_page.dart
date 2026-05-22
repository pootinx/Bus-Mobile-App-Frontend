import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bus_app/features/onboarding/controllers/onboarding_controller.dart';
import 'package:bus_app/features/onboarding/models/onboarding_models.dart';
import 'package:bus_app/core/theme/app_theme.dart';

class OnboardingPage extends StatelessWidget {
  const OnboardingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(OnboardingController());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(controller),
            Expanded(
              child: PageView(
                controller: controller.pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: const [
                  _ProfileStep(),
                  _TransportStep(),
                  _PreferencesStep(),
                  _ReviewStep(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(OnboardingController controller) {
    return Obx(() => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 20, 8),
      child: Column(
        children: [
          Row(
            children: [
              if (controller.currentStep.value > 0)
                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: controller.previousStep,
                )
              else
                const SizedBox(width: 48),
              const Spacer(),
              Text(
                'Step ${controller.currentStep.value + 1}/${controller.totalSteps}',
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (controller.currentStep.value + 1) / controller.totalSteps,
                minHeight: 6,
                backgroundColor: Colors.grey[200],
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final isArabic = Get.locale?.languageCode == 'ar';
    final textStyle = isArabic ? GoogleFonts.ibmPlexSansArabic() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.person_outline_rounded, size: 48, color: AppTheme.primaryBlue),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'المعلومات الشخصية' : 'Personal Information',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: textStyle?.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'أخبرنا عن نفسك' : 'Tell us about yourself',
              style: TextStyle(color: Colors.grey[600], fontFamily: textStyle?.fontFamily),
            ),
            const SizedBox(height: 24),
            _buildField('Full Name', 'الاسم الكامل', c.nameController, Icons.person, textStyle: textStyle),
            const SizedBox(height: 16),
            _buildField('Phone Number', 'رقم الهاتف', c.phoneController, Icons.phone, keyboardType: TextInputType.phone, textStyle: textStyle),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Gender',
                    labelAr: 'الجنس',
                    value: c.selectedGender,
                    items: ['Male', 'Female'],
                    itemsAr: ['ذكر', 'أنثى'],
                    onChanged: (v) => c.selectedGender = v,
                    textStyle: textStyle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildField('Age', 'العمر', c.ageController, Icons.cake, keyboardType: TextInputType.number, textStyle: textStyle),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildDropdown(
              label: 'Professional Status',
              labelAr: 'الحالة المهنية',
              value: c.selectedStatus,
              items: ProfessionalStatus.optionsEn,
              itemsAr: ProfessionalStatus.options,
              onChanged: (v) => c.selectedStatus = v,
              textStyle: textStyle,
            ),
            const SizedBox(height: 16),
            _buildField('City', 'مدينة السكن', c.cityController, Icons.location_city, textStyle: textStyle),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: c.nextStep,
                child: Text(isArabic ? 'متابعة' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransportStep extends StatelessWidget {
  const _TransportStep();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final isArabic = Get.locale?.languageCode == 'ar';
    final textStyle = isArabic ? GoogleFonts.ibmPlexSansArabic() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.directions_bus_rounded, size: 48, color: AppTheme.primaryBlue),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'عادة التنقل' : 'Transport Habits',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: textStyle?.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'ساعدنا في فهم تنقلاتك اليومية' : 'Help us understand your daily commute',
              style: TextStyle(color: Colors.grey[600], fontFamily: textStyle?.fontFamily),
            ),
            const SizedBox(height: 24),
            _buildField(isArabic ? 'الخط الرئيسي' : 'Main Bus Line', 'الخط الرئيسي', c.mainLineController, Icons.route, textStyle: textStyle),
            const SizedBox(height: 12),
            _buildField(isArabic ? 'الخط الثانوي' : 'Secondary Line', 'الخط الثانوي', c.secondaryLineController, Icons.route, optional: true, textStyle: textStyle),
            const SizedBox(height: 12),
            _buildField(isArabic ? 'خط آخر' : 'Other Line', 'خط آخر', c.otherLineController, Icons.route, optional: true, textStyle: textStyle),
            const SizedBox(height: 12),
            _buildField(isArabic ? 'محطة الركوب' : 'Boarding Station', 'محطة الركوب', c.stationController, Icons.location_on, textStyle: textStyle),
            const SizedBox(height: 16),
            _buildField(isArabic ? 'وقت الانتظار (دقيقة)' : 'Daily Wait Time (min)', 'وقت الانتظار', c.waitingTimeController, Icons.timer, textStyle: textStyle),
            const SizedBox(height: 12),
            _buildField(isArabic ? 'مدة الرحلة (دقيقة)' : 'Daily Travel Time (min)', 'مدة الرحلة', c.travelTimeController, Icons.schedule, textStyle: textStyle),
            const SizedBox(height: 12),
            _buildField(isArabic ? 'وقت الاستخدام المعتاد' : 'Usual Travel Time', 'وقت الاستخدام', c.usageTimeController, Icons.wb_twilight, textStyle: textStyle),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: 'Payment Method',
                    labelAr: 'طريقة الدفع',
                    value: c.selectedPayment,
                    items: ['Cash', 'Card', 'App', 'T-Pass'],
                    itemsAr: ['نقدا', 'بطاقة', 'تطبيق', 'تذكرة'],
                    onChanged: (v) => c.selectedPayment = v,
                    textStyle: textStyle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: Text(
                isArabic ? 'هل تواجه مشاكل في شراء التذاكر' : 'Trouble buying tickets?',
                style: TextStyle(fontFamily: textStyle?.fontFamily),
              ),
              value: c.ticketIssuesValue,
              onChanged: (v) => c.ticketIssuesValue = v ?? false,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 24),
            _buildBottomNav(c, isArabic, textStyle, canProceed: true),
          ],
        ),
      ),
    );
  }
}

class _PreferencesStep extends StatelessWidget {
  const _PreferencesStep();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final isArabic = Get.locale?.languageCode == 'ar';
    final textStyle = isArabic ? GoogleFonts.ibmPlexSansArabic() : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.tune_rounded, size: 48, color: AppTheme.primaryBlue),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'التفضيلات' : 'Preferences',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: textStyle?.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'ضبط تفضيلات التطبيق' : 'Set your app preferences',
              style: TextStyle(color: Colors.grey[600], fontFamily: textStyle?.fontFamily),
            ),
            const SizedBox(height: 32),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(isArabic ? 'تفعيل الإشعارات' : 'Enable notifications', style: TextStyle(fontFamily: textStyle?.fontFamily)),
                      subtitle: Text(isArabic ? 'استقبل تنبيهات الاستطلاعات والتحديثات' : 'Receive survey alerts and updates', style: TextStyle(fontFamily: textStyle?.fontFamily)),
                      value: true,
                      onChanged: (_) {},
                    ),
                    const Divider(),
                    ListTile(
                      title: Text(isArabic ? 'اللغة المفضلة' : 'Preferred Language', style: TextStyle(fontFamily: textStyle?.fontFamily)),
                      trailing: DropdownButton<String>(
                        value: Get.locale?.languageCode ?? 'en',
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English')),
                          DropdownMenuItem(value: 'fr', child: Text('Français')),
                          DropdownMenuItem(value: 'ar', child: Text('العربية')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            Get.updateLocale(Locale(v));
                          }
                        },
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      title: Text(isArabic ? 'الوضع الداكن' : 'Dark Mode', style: TextStyle(fontFamily: textStyle?.fontFamily)),
                      value: Get.isDarkMode,
                      onChanged: (_) {
                        Get.changeThemeMode(
                          Get.isDarkMode ? ThemeMode.light : ThemeMode.dark,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildBottomNav(c, isArabic, textStyle, canProceed: true),
          ],
        ),
      ),
    );
  }
}

class _ReviewStep extends StatelessWidget {
  const _ReviewStep();

  @override
  Widget build(BuildContext context) {
    final c = Get.find<OnboardingController>();
    final isArabic = Get.locale?.languageCode == 'ar';
    final textStyle = isArabic ? GoogleFonts.ibmPlexSansArabic() : null;

    return Obx(() => SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Directionality(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.checklist_rounded, size: 48, color: AppTheme.primaryBlue),
            const SizedBox(height: 12),
            Text(
              isArabic ? 'مراجعة وتأكيد' : 'Review & Submit',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontFamily: textStyle?.fontFamily,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isArabic ? 'يرجى مراجعة معلوماتك' : 'Please review your information',
              style: TextStyle(color: Colors.grey[600], fontFamily: textStyle?.fontFamily),
            ),
            const SizedBox(height: 24),
            _buildReviewCard(
              context,
              title: isArabic ? 'الملف الشخصي' : 'Profile',
              icon: Icons.person_outline,
              items: [
                _ReviewItem(label: isArabic ? 'الاسم' : 'Name', value: c.nameController.text),
                _ReviewItem(label: isArabic ? 'الهاتف' : 'Phone', value: c.phoneController.text),
                _ReviewItem(label: isArabic ? 'الجنس' : 'Gender', value: c.selectedGender ?? ''),
                _ReviewItem(label: isArabic ? 'العمر' : 'Age', value: c.ageController.text),
                _ReviewItem(label: isArabic ? 'الحالة' : 'Status', value: c.selectedStatus ?? ''),
                _ReviewItem(label: isArabic ? 'المدينة' : 'City', value: c.cityController.text),
              ],
              onEdit: () => c.pageController.jumpToPage(0),
              textStyle: textStyle,
            ),
            const SizedBox(height: 12),
            _buildReviewCard(
              context,
              title: isArabic ? 'التنقل' : 'Transport',
              icon: Icons.directions_bus_outlined,
              items: [
                _ReviewItem(label: isArabic ? 'الخط الرئيسي' : 'Main Line', value: c.mainLineController.text),
                _ReviewItem(label: isArabic ? 'وقت الانتظار' : 'Wait Time', value: '${c.waitingTimeController.text} min'),
                _ReviewItem(label: isArabic ? 'مدة الرحلة' : 'Travel Time', value: '${c.travelTimeController.text} min'),
                _ReviewItem(label: isArabic ? 'وسيلة الدفع' : 'Payment', value: c.selectedPayment ?? ''),
              ],
              onEdit: () => c.pageController.jumpToPage(1),
              textStyle: textStyle,
            ),
            const SizedBox(height: 12),
            _buildReviewCard(
              context,
              title: isArabic ? 'التفضيلات' : 'Preferences',
              icon: Icons.tune,
              items: [
                _ReviewItem(label: isArabic ? 'الإشعارات' : 'Notifications', value: isArabic ? 'مفعلة' : 'Enabled'),
                _ReviewItem(label: isArabic ? 'اللغة' : 'Language', value: (Get.locale?.languageCode ?? 'en').toUpperCase()),
              ],
              onEdit: () => c.pageController.jumpToPage(2),
              textStyle: textStyle,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: c.isLoading.value ? null : c.submitOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: c.isLoading.value
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isArabic ? 'إكمال الإعداد' : 'Complete Setup',
                      style: TextStyle(fontSize: 16, fontFamily: textStyle?.fontFamily),
                    ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildReviewCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<_ReviewItem> items,
    required VoidCallback onEdit,
    TextStyle? textStyle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontFamily: textStyle?.fontFamily,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text('Edit'),
                ),
              ],
            ),
            const Divider(),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      item.label,
                      style: TextStyle(color: Colors.grey, fontFamily: textStyle?.fontFamily),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.value,
                      style: TextStyle(fontWeight: FontWeight.w500, fontFamily: textStyle?.fontFamily),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}

class _ReviewItem {
  final String label;
  final String value;
  _ReviewItem({required this.label, required this.value});
}

Widget _buildField(
  String label,
  String labelAr,
  TextEditingController controller,
  IconData icon, {
  bool optional = false,
  TextInputType? keyboardType,
  TextStyle? textStyle,
}) {
  final isArabic = Get.locale?.languageCode == 'ar';
  return TextField(
    controller: controller,
    keyboardType: keyboardType,
    style: TextStyle(fontFamily: textStyle?.fontFamily),
    decoration: InputDecoration(
      labelText: isArabic ? labelAr : label,
      labelStyle: TextStyle(fontFamily: textStyle?.fontFamily),
      hintStyle: TextStyle(fontFamily: textStyle?.fontFamily),
      prefixIcon: Icon(icon),
      suffixText: optional ? (isArabic ? 'اختياري' : 'optional') : null,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

Widget _buildDropdown({
  required String label,
  required String labelAr,
  required String? value,
  required List<String> items,
  required List<String> itemsAr,
  required ValueChanged<String?> onChanged,
  TextStyle? textStyle,
}) {
  final isArabic = Get.locale?.languageCode == 'ar';
  return DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(
      labelText: isArabic ? labelAr : label,
      labelStyle: TextStyle(fontFamily: textStyle?.fontFamily),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    style: TextStyle(fontFamily: textStyle?.fontFamily),
    items: (isArabic ? itemsAr : items).map((item) =>
      DropdownMenuItem(value: item, child: Text(item, style: TextStyle(fontFamily: textStyle?.fontFamily)))
    ).toList(),
    onChanged: onChanged,
  );
}

Widget _buildBottomNav(
  OnboardingController c,
  bool isArabic,
  TextStyle? textStyle, {
  required bool canProceed,
}) {
  return Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          onPressed: c.previousStep,
          icon: Icon(isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded, size: 18),
          label: Text(isArabic ? 'السابق' : 'Back'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        flex: 2,
        child: ElevatedButton.icon(
          onPressed: canProceed ? c.nextStep : null,
          icon: Icon(isArabic ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 18),
          label: Text(isArabic ? 'متابعة' : 'Continue'),
        ),
      ),
    ],
  );
}
