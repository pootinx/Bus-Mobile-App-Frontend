
import 'package:bus_app/features/authentication/services/profile_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // Controllers to manage the text fields' state.
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    // Get the user data from the ProfileService.
    final user = ProfileService.to.user;

    // Initialize the controllers with the user's current data.
    _nameController = TextEditingController(text: user?.fullName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    // Clean up the controllers when the widget is removed from the tree.
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Get.back(),
        ),
        title: const Text("Edit Profile", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        child: Column(
          children: [
            Stack(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(60),
                    child: Image.network(
                      "https://picsum.photos/200", // Placeholder
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                // TODO: Implement image picking logic
              },
              child: const Text("Edit image", style: TextStyle(color: Colors.blue)),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined),
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  // The email is not editable, so the suffix icon is not needed.
                  // suffixIcon: Icon(Icons.cancel_outlined)
                ),
              readOnly: true, // The email is the user's identifier and should not be changed.
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_outline),
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            // Note: Implementing a secure "Change Password" feature is a complex task
            // that involves re-authentication and is left for future implementation.
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Implement save logic.
                  // This will involve calling a method in the ProfileService to update
                  // the user's data in Firestore.
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
