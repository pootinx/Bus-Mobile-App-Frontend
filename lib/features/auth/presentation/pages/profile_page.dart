
import 'package:bus_app/features/auth/presentation/pages/edit_profile_page.dart';
import 'package:bus_app/features/auth/services/auth_service.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the services.
    final profileService = ProfileService.to;
    final authService = AuthService.to;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: Obx(() {
        // Reactively listen to the user model from the ProfileService.
        final userModel = profileService.user;

        // If the user model is null, it means we are either logging out or the data
        // hasn't been loaded yet. A loading spinner is a safe default.
        if (userModel == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // If we have a user, build the profile view.
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Stack(
                    children: [
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(40),
                          child: Image.network("https://picsum.photos/200", fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            color: Colors.blue,
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.edit, color: Colors.white, size: 15),
                            onPressed: () => Get.to(() => const EditProfilePage()),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userModel.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      Text(userModel.email),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 30),
              const Text("Account settings", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildProfileMenuItem(title: "Personal information", onTap: () {}, icon: Icons.arrow_forward_ios),
              _buildProfileMenuItem(title: "Notifications", onTap: () {}, icon: Icons.arrow_forward_ios),
              const SizedBox(height: 30),
              const Text("Help & Support", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 10),
              _buildProfileMenuItem(title: "Privacy policy", onTap: () {}, icon: Icons.arrow_forward_ios),
              _buildProfileMenuItem(title: "Terms & Conditions", onTap: () {}, icon: Icons.arrow_forward_ios),
              const SizedBox(height: 20),
              ListTile(
                title: const Text("Log out", style: TextStyle(color: Colors.red)),
                // Call the signOut method from the AuthService.
                onTap: () => authService.signOut(),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildProfileMenuItem({required String title, required VoidCallback onTap, IconData? icon}) {
    return ListTile(
      title: Text(title),
      trailing: Icon(icon, size: 16),
      onTap: onTap,
    );
  }
}
