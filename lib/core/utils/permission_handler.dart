import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import '../../features/map/presentation/widgets/location_disclosure_dialog.dart';

class PermissionHandler {
  static Future<bool> checkLocationStatus() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  /// Checks and requests location permission with a prominent disclosure.
  static Future<bool> handleLocationPermission(BuildContext context) async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Location services are disabled. Please enable them.')));
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      
      // 2. PROMINENT DISCLOSURE: Show dialog BEFORE requesting permission
      final userAgreed = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const LocationDisclosureDialog(),
      );

      if (userAgreed != true) {
        return false;
      }

      // 3. Request Permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location permission denied')));
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Location permissions are permanently denied, we cannot request permissions.')));
      return false;
    }

    return true;
  }
}
