import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng? _cachedLocation;
  // This flag tracks if we have already prompted the user for permission in this session.
  bool _permissionRequestedThisSession = false;

  /// Fetches the current location.
  ///
  /// This method is designed to be safe to call multiple times.
  /// - It caches the location after the first successful retrieval.
  /// - It only requests permission from the user *once* per session.
  Future<LatLng> getCurrentLocation() async {
    // 1. If we have a cached location, return it immediately.
    if (_cachedLocation != null) {
      return _cachedLocation!;
    }

    // 2. Check the current permission status.
    LocationPermission permission = await Geolocator.checkPermission();

    // 3. Handle the "denied forever" case.
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable them in the app settings.');
    }

    // 4. If permission is denied, request it, but only once per session.
    if (permission == LocationPermission.denied) {
      // If we've already asked and been denied in this session, don't ask again.
      if (_permissionRequestedThisSession) {
        throw Exception('Location permissions were denied during this session.');
      }

      // Mark that we are about to request permission.
      _permissionRequestedThisSession = true;
      permission = await Geolocator.requestPermission();

      // If the user *still* denies it, throw an exception.
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied.');
      }
    }
    
    // 5. If we've reached here, permission is granted (either was, or is now).
    // Get the position, cache it, and return it.
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _cachedLocation = LatLng(position.latitude, position.longitude);
    return _cachedLocation!;
  }

  /// Clears the cached location. This might be useful on user logout.
  void clearCache() {
    _cachedLocation = null;
    _permissionRequestedThisSession = false;
  }
}
