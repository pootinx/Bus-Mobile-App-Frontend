import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:bus_app/core/controllers/theme_controller.dart';
import 'package:bus_app/core/services/localization_service.dart';
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = Get.find<ProfileService>();
    final authService = Get.find<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Get.to(() => const NotificationsPage()),
          ),
        ],
      ),
      body: Obx(() {
        final profile = profileService.user;
        if (profile == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 48,
                backgroundColor: AppTheme.primaryBlue.withOpacity(0.1),
                child: Text(
                  _getInitials(profile.fullName),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(profile.fullName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              Text(profile.email, style: TextStyle(color: Colors.grey[600])),
              const SizedBox(height: 24),

              // Info Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personal Info', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Divider(),
                      _infoRow(Icons.phone, 'Phone', profile.phone.isEmpty ? 'Not set' : profile.phone),
                      _infoRow(Icons.wc, 'Gender', profile.gender.isEmpty ? 'Not set' : profile.gender),
                      _infoRow(Icons.cake, 'Age', profile.age > 0 ? '${profile.age}' : 'Not set'),
                      _infoRow(Icons.work, 'Status', profile.professionalStatus.isEmpty ? 'Not set' : profile.professionalStatus),
                      _infoRow(Icons.location_city, 'City', profile.city.isEmpty ? 'Not set' : profile.city),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Stats Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Account', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Divider(),
                      _infoRow(Icons.check_circle, 'Onboarding', profile.onboardingCompleted ? 'Completed' : 'Pending'),
                      _infoRow(Icons.verified_user, 'Email Verified', authService.firebaseUser?.emailVerified == true ? 'Yes' : 'No'),
                      if (profile.createdAt != null)
                        _infoRow(Icons.calendar_today, 'Joined', _formatDate(profile.createdAt!)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Settings Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Settings', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      const Divider(),
                      
                      // Dark Mode Toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.dark_mode, size: 20, color: Colors.grey[500]),
                                const SizedBox(width: 12),
                                Text('Dark Mode', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                            Obx(() {
                              final themeController = Get.find<ThemeController>();
                              return Switch(
                                value: themeController.isDarkMode,
                                onChanged: (val) {
                                  themeController.toggleTheme();
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                      
                      // Language Selector
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.language, size: 20, color: Colors.grey[500]),
                                const SizedBox(width: 12),
                                Text('Language', style: TextStyle(color: Colors.grey[600])),
                              ],
                            ),
                            Obx(() {
                              final locService = Get.find<LocalizationService>();
                              return DropdownButton<String>(
                                value: locService.currentLocale.languageCode,
                                underline: const SizedBox(),
                                items: const [
                                  DropdownMenuItem(value: 'en', child: Text('English')),
                                  DropdownMenuItem(value: 'fr', child: Text('Français')),
                                  DropdownMenuItem(value: 'ar', child: Text('العربية')),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    locService.updateLocale(val);
                                  }
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Logout
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => authService.signOut(),
                  icon: const Icon(Icons.logout, color: Colors.red),
                  label: const Text('Logout', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[500]),
          const SizedBox(width: 12),
          SizedBox(width: 100, child: Text(label, style: TextStyle(color: Colors.grey[600]))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name[0].toUpperCase();
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
