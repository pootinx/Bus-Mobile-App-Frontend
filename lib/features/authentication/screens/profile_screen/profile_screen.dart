
import 'package:bus_app/features/authentication/screens/profile_screen/edit_profile_screen.dart';
import 'package:bus_app/features/authentication/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    // As soon as the screen is initialized, check the user's validity.
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await user.reload();
        // After reload, check the source of truth again.
        if (FirebaseAuth.instance.currentUser == null) {
          // If the user is null, they have been deleted. Sign out immediately.
          AuthService.to.signOut();
        }
      } on FirebaseAuthException catch (e) {
        // If reload fails because the user is not found or disabled, sign out.
        if (e.code == 'user-not-found' || e.code == 'user-disabled') {
          AuthService.to.signOut();
        }
      } catch (e) {
        // Log other potential errors without crashing.
        debugPrint("An error occurred while checking user status: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      // Use a reactive Obx widget to listen to authentication state changes.
      body: Obx(() {
        final user = AuthService.to.firebaseUser.value;

        // If user is null, it means they are logged out or their session is
        // invalid. Show a safe loading spinner while the auth service
        // redirects them to the login screen. This prevents any UI from
        // trying to build with invalid data.
        if (user == null) {
          return const Center(child: CircularProgressIndicator());
        }

        // If the user is valid, and only in this case, build the actual
        // profile UI by passing the guaranteed non-null user to a dedicated widget.
        return _ProfileView(user: user);
      }),
    );
  }
}

// This is a new, separate widget that ONLY builds the Profile UI.
// It can only be created when it is passed a valid, non-null User object.
// This completely isolates the data-dependent UI and prevents the race condition.
class _ProfileView extends StatelessWidget {
  final User user;
  const _ProfileView({required this.user});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              String firstName = '';
              String lastName = '';
              Widget statusMessage = const SizedBox.shrink();

              if (snapshot.hasError) {
                statusMessage = const Center(child: Text('Something went wrong'));
              } else if (!snapshot.hasData || !snapshot.data!.exists) {
                statusMessage = const Center(child: Text('User data not found.'));
              } else {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                firstName = userData['firstName'] ?? '';
                lastName = userData['lastName'] ?? '';
              }

              return Column(
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
                              child: Image.network(
                                "https://picsum.photos/200", // Placeholder
                                fit: BoxFit.cover,
                              ),
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
                                onPressed: () {
                                  Get.to(() => const EditProfileScreen());
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$firstName $lastName'.trim(),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          // This is safe because 'user' is guaranteed to be non-null here.
                          Text(user.email ?? 'No email'),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  statusMessage,
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          const Text("Account settings",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildProfileMenuItem(
              title: "Personal information",
              onTap: () {},
              icon: Icons.arrow_forward_ios),
          _buildProfileMenuItem(
              title: "Notifications",
              onTap: () {},
              icon: Icons.arrow_forward_ios),
          _buildProfileMenuItem(
              title: "Time spent", onTap: () {}, icon: Icons.arrow_forward_ios),
          _buildProfileMenuItem(
              title: "Following", onTap: () {}, icon: Icons.arrow_forward_ios),
          const SizedBox(height: 30),
          const Text("Help & Support",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 10),
          _buildProfileMenuItem(
              title: "Privacy policy",
              onTap: () {},
              icon: Icons.arrow_forward_ios),
          _buildProfileMenuItem(
              title: "Terms & Conditions",
              onTap: () {},
              icon: Icons.arrow_forward_ios),
          _buildProfileMenuItem(
              title: "FAQ & Help", onTap: () {}, icon: Icons.arrow_forward_ios),
          const SizedBox(height: 20),
          ListTile(
            title: const Text("Log out", style: TextStyle(color: Colors.red)),
            onTap: () {
              AuthService.to.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProfileMenuItem(
      {required String title, required VoidCallback onTap, IconData? icon}) {
    return ListTile(
      title: Text(title),
      trailing: Icon(icon, size: 16),
      onTap: onTap,
    );
  }
}
