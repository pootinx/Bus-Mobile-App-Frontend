import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  LatLng? _cachedLocation;

  /// Fetches the current location.
  /// 
  /// NOTE: This method assumes that location permissions have already been 
  /// handled by the caller (using PermissionHandler).
  Future<LatLng> getCurrentLocation() async {
    // 1. If we have a cached location, return it immediately.
    if (_cachedLocation != null) {
      return _cachedLocation!;
    }

    // 2. Check the current permission status.
    LocationPermission permission = await Geolocator.checkPermission();

    // 3. Handle the "denied" cases.
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are denied. Please enable them in the app settings.');
    }
    
    // 4. If we've reached here, permission is granted.
    // Get the position, cache it, and return it.
    Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    _cachedLocation = LatLng(position.latitude, position.longitude);
    return _cachedLocation!;
  }

  /// Clears the cached location.
  void clearCache() {
    _cachedLocation = null;
  }
}
