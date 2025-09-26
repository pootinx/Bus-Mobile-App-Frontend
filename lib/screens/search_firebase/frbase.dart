import 'dart:async';
import 'package:bus_app/models/route_frbase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

class FirestoreRouteServiceV2 {
  final latlng.Distance _distance = const latlng.Distance();

  // Step 1: Get user GPS location
  Future<Position> getUserLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions denied');
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

  // Step 2: Get city name from GPS
  Future<String?> getLocationNameFromCoordinates(double latitude, double longitude) async {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isNotEmpty) {
      return placemarks.first.locality?.toLowerCase();
    }
    return null;
  }

  Future<String?> getCityNameFromCoordinates(double latitude, double longitude) async {
  try {
    final placemarks = await placemarkFromCoordinates(latitude, longitude);

    if (placemarks.isNotEmpty) {
      final place = placemarks.first;

      // Try to get the main city name in fallback order
      final city = place.subAdministrativeArea ??
                   place.locality ??
                   place.administrativeArea;

      return city?.toLowerCase().trim();
    }
  } catch (e) {
    print("❌ Erreur lors de la détection de la ville : $e");
  }

  return null;
}

  // Step 3 & 4: Get cities from Firestore
  Future<List<String>> getCitiesFromFirestore() async {
    final snapshot = await FirebaseFirestore.instance.collection('cities').get();
    return snapshot.docs
        .map((doc) => doc['name'].toString().toLowerCase().trim())
        .toList();
  }

  // Step 5: Match detected city with Firestore city names
  String? matchCity(String? detectedCity, List<String> firestoreCities) {
    if (detectedCity == null) return null;
    for (final city in firestoreCities) {
      if (detectedCity.contains(city) || city.contains(detectedCity)) {
        return city;
      }
    }
    return null;
  }


Future<List<FirestoreRouteResultV1>> searchCityRoutes({
  required String cityName,
  required String start,
  required String end,
  DateTime? targetTime,
}) async {
  List<FirestoreRouteResultV1> results = [];

  try {
    final querySnapshot = await FirebaseFirestore.instance.collection(cityName).get();

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
      final stopNames = stops.map((s) => (s['name'] ?? '').toString()).toList();

      final hasStart = _containsSearchTerm(stopNames, start);
      final hasEnd = _containsSearchTerm(stopNames, end);
      if (!hasStart || !hasEnd) continue;

      // Get start and end stop coordinates
      latlng.LatLng? startStopCoords;
      latlng.LatLng? endStopCoords;

      for (final stop in stops) {
        final name = (stop['name'] ?? '').toString().toLowerCase().trim();
        if (startStopCoords == null &&
            _normalizeSearchTerm(name).contains(_normalizeSearchTerm(start))) {
          if (stop['lat'] != null && stop['lon'] != null) {
            startStopCoords = latlng.LatLng(stop['lat'], stop['lon']);
          }
        }
        if (endStopCoords == null &&
            _normalizeSearchTerm(name).contains(_normalizeSearchTerm(end))) {
          if (stop['lat'] != null && stop['lon'] != null) {
            endStopCoords = latlng.LatLng(stop['lat'], stop['lon']);
          }
        }
      }

      if (startStopCoords == null || endStopCoords == null) continue;

      // Decode polyline
      final polylineEncoded = data['polyline'];
      final polylineDecoded = (polylineEncoded != null && polylineEncoded.isNotEmpty)
          ? decodePolyline(polylineEncoded)
          : generateSimplePolyline(stops);

      if (polylineDecoded.isEmpty) continue;

      final distanceKm = calculateDistanceFromPolyline(polylineDecoded).toStringAsFixed(2);
      final colorHex = (data['color'] ?? '#007bff').replaceAll('#', '');
      final color = int.tryParse('FF$colorHex', radix: 16) ?? 0xFF007BFF;

      final trips = List<Map<String, dynamic>>.from(data['trips'] ?? []);

      for (final trip in trips) {
        final rawStart = trip['startTime'] ?? "08:00:00";
        final rawEnd = trip['endTime'] ?? "18:00:00";

        if (targetTime != null) {
          try {
            final parts = rawStart.split(':').map(int.parse).toList();
            final tripTime = DateTime(
              targetTime.year,
              targetTime.month,
              targetTime.day,
              parts[0],
              parts[1],
              parts[2],
            );
            if (tripTime.isBefore(targetTime)) continue;
          } catch (e) {
            print('⚠️ Invalid time: $rawStart');
            continue;
          }
        }

        results.add(FirestoreRouteResultV1(
          polyline: extractSubPolyline(polylineDecoded, startStopCoords, endStopCoords),
          stops: stops,
          lineName: data['route_name'] ?? doc.id,
          colorValue: color,
          startTime: rawStart,
          endTime: rawEnd,
          busDistance: distanceKm,
          startStopCoords: startStopCoords,
          endStopCoords: endStopCoords,
          distanceToStart: 0,
          distanceToEnd: 0,
          walkingTimeToStart: 0,
          walkingTimeToEnd: 0, startAddress: '', endAddress: '', startCoords: latlng.LatLng(0, 0), endCoords: latlng.LatLng(0, 0),
        ));
      }
    }
  } catch (e) {
    print('❌ Error in searchCityRoutes: $e');
  }

  if (targetTime != null) {
    results.sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  return results;
}


List<latlng.LatLng> extractSubPolyline(
  List<latlng.LatLng> fullPolyline,
  latlng.LatLng startStop,
  latlng.LatLng endStop,
) {
  int findClosestIndex(latlng.LatLng point) {
    double minDist = double.infinity;
    int index = 0;
    for (int i = 0; i < fullPolyline.length; i++) {
      final dist = _distance(point, fullPolyline[i]);
      if (dist < minDist) {
        minDist = dist;
        index = i;
      }
    }
    return index;
  }

  int startIndex = findClosestIndex(startStop);
  int endIndex = findClosestIndex(endStop);

  if (startIndex > endIndex) {
    final temp = startIndex;
    startIndex = endIndex;
    endIndex = temp;
  }

  return fullPolyline.sublist(startIndex, endIndex + 1);
}


Future<List<FirestoreRouteResultV1>> searchCityRoutesByCoords({
  required String cityName,
  required latlng.LatLng startCoords,
  required latlng.LatLng endCoords,
  required String startAddress,
  required String endAddress,
  DateTime? targetTime,
}) async {
  List<FirestoreRouteResultV1> results = [];
  try {
    final querySnapshot = await FirebaseFirestore.instance.collection(cityName).get();
    targetTime ??= DateTime.now(); // Use current time if null
//     targetTime ??= DateTime(
//   DateTime.now().year,
//   DateTime.now().month,
//   DateTime.now().day,
//   10, 0, 0,
// );
// Use current time if null

    print("cityName: $cityName");
    print("startCoords: $startCoords");
    print("endCoords: $endCoords");
    print("startAddress: $startAddress");
    print("endAddress: $endAddress");
    print("targetTime: $targetTime");

    // print("querySnapshot: $querySnapshot");

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
      print("stops: $stops");

      final nearestStart = findNearestStop(startCoords, stops);
      final nearestEnd = findNearestStop(endCoords, stops);

      if (nearestStart == null || nearestEnd == null) continue;

      final distanceToStartMeters = const latlng.Distance()(startCoords, nearestStart);
      final distanceToEndMeters = const latlng.Distance()(nearestEnd, endCoords);

      final walkToStart = Duration(seconds: (distanceToStartMeters / 1.4).round());
      final walkToEnd = Duration(seconds: (distanceToEndMeters / 1.4).round());

      final userArrivalTime = targetTime.add(walkToStart);

      final polylineEncoded = data['polyline'];
      final polylineDecoded = (polylineEncoded != null && polylineEncoded.isNotEmpty)
          ? decodePolyline(polylineEncoded)
          : generateSimplePolyline(stops);
      if (polylineDecoded.isEmpty) continue;

      final colorHex = (data['color'] ?? '#007bff').replaceAll('#', '');
      final color = int.tryParse('FF$colorHex', radix: 16) ?? 0xFF007BFF;

      final trips = List<Map<String, dynamic>>.from(data['trips'] ?? []);
      for (final trip in trips) {
        final rawStart = trip['startTime'] ?? "08:00:00";

        try {
          final parts = rawStart.split(':').map(int.parse).toList();
          final tripStartTime = DateTime(
            userArrivalTime.year,
            userArrivalTime.month,
            userArrivalTime.day,
            parts[0],
            parts[1],
            parts[2],
          );

          if (tripStartTime.isBefore(userArrivalTime)) continue;

          final partialPolyline = extractSubPolyline(polylineDecoded, nearestStart, nearestEnd);
          final subDistanceKm = calculateDistanceFromPolyline(partialPolyline).toStringAsFixed(2);
          final Duration rideDuration = estimateDuration(double.parse(subDistanceKm), 40);
          if (subDistanceKm == "0.00") continue;
          final estimatedArrival = tripStartTime.add(rideDuration);

          final formattedArrival = "${estimatedArrival.hour.toString().padLeft(2, '0')}:"
              "${estimatedArrival.minute.toString().padLeft(2, '0')}";

          print("endAddress: $endAddress");

          results.add(FirestoreRouteResultV1(
            polyline: partialPolyline,
            stops: stops,
            lineName: data['route_name'] ?? doc.id,
            colorValue: color,
            startTime: rawStart,
            endTime: formattedArrival,
            busDistance: subDistanceKm,
            startStopCoords: nearestStart,
            endStopCoords: nearestEnd,
            distanceToStart: distanceToStartMeters,
            distanceToEnd: distanceToEndMeters,
            walkingTimeToStart: walkToStart.inMinutes,
            walkingTimeToEnd: walkToEnd.inMinutes,
            startAddress: startAddress,
            endAddress: endAddress,
            startCoords: startCoords,
            endCoords: endCoords,
          ));
        } catch (e) {
          print('⚠️ Trip time parse error: $rawStart → $e');
        }
      }
    }
  } catch (e) {
    print('❌ Error in searchCityRoutesByCoords: $e');
  }

  results.sort((a, b) => a.startTime.compareTo(b.startTime));
  // return results.take(5).toList(); // Return only top 3
  return results; // Return only top 3
}


Duration estimateDuration(double distanceKm, double speedKmh) {
  final speedMs = speedKmh * 1000 / 3600; // km/h → m/s
  final distanceMeters = distanceKm * 1000;

  final durationSeconds = distanceMeters / speedMs;
  return Duration(seconds: durationSeconds.round());
}






  // Step 7 & 8: Find nearest stop to given point
  latlng.LatLng? findNearestStop(latlng.LatLng point, List<Map<String, dynamic>> stops) {
    double minDistance = double.infinity;
    latlng.LatLng? nearest;
    for (var stop in stops) {
      if (stop['lat'] == null || stop['lon'] == null) continue;
      final stopPoint = latlng.LatLng(stop['lat'], stop['lon']);
      final d = _distance(point, stopPoint);
      if (d < minDistance) {
        minDistance = d;
        nearest = stopPoint;
      }
    }
    return nearest;
  }

  // Utility: Decode polyline string
  List<latlng.LatLng> decodePolyline(String encoded) {
    List<latlng.LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1F) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;

      points.add(latlng.LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  List<latlng.LatLng> generateSimplePolyline(List<Map<String, dynamic>> stops) {
    if (stops.isEmpty) return [];
    List<latlng.LatLng> polyline = [];
    for (var stop in stops) {
      if (stop['lat'] != null && stop['lon'] != null) {
        polyline.add(latlng.LatLng(stop['lat'].toDouble(), stop['lon'].toDouble()));
      }
    }
    return polyline;
  }

  double calculateDistanceFromPolyline(List<latlng.LatLng> polyline) {
    if (polyline.isEmpty) return 0;
    double totalDistance = 0;
    for (int i = 0; i < polyline.length - 1; i++) {
      totalDistance += _distance(polyline[i], polyline[i + 1]);
    }
    return totalDistance / 1000; // in km
  }

  bool _containsSearchTerm(List<String> texts, String searchTerm) {
    // print("object 0");
    // print("texts: $texts");
    // print("searchTerm: $searchTerm");
    final normalizedSearch = _normalizeSearchTerm(searchTerm);
    return texts.any((text) =>
        _normalizeSearchTerm(text).contains(normalizedSearch) ||
        normalizedSearch.contains(_normalizeSearchTerm(text)));
  }

  String _normalizeSearchTerm(String term) {
    return term.toLowerCase()
        .replaceAll(RegExp(r'[àáâãäå]'), 'a')
        .replaceAll(RegExp(r'[èéêë]'), 'e')
        .replaceAll(RegExp(r'[ìíîï]'), 'i')
        .replaceAll(RegExp(r'[òóôõö]'), 'o')
        .replaceAll(RegExp(r'[ùúûü]'), 'u')
        .replaceAll(RegExp(r'[ç]'), 'c')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
