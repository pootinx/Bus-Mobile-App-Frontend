import 'package:bus_app/features/auth/models/user_model.dart';
import 'package:bus_app/features/auth/services/profile_service.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfileController extends GetxController {
  final ProfileService _profileService = Get.find<ProfileService>();
  
  final RxBool isLoading = true.obs;
  final Rx<UserModel?> userModel = Rx<UserModel?>(null);

  @override
  void onInit() {
    super.onInit();
    _loadInitialProfile();
  }

  Future<void> _loadInitialProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await fetchProfile(user);
    } else {
      isLoading.value = false;
    }
  }

  Future<void> fetchProfile(User user) async {
    try {
      isLoading.value = true;
      await _profileService.fetchUserProfile(user);
      userModel.value = _profileService.user;
    } finally {
      isLoading.value = false;
    }
  }

  void clearProfile() {
    userModel.value = null;
    _profileService.clearUserProfile();
  }
}
