import 'package:bus_app/models/directions_response.dart' hide LatLng;
import 'package:bus_app/models/firestore_route_result.dart';
import 'package:bus_app/models/route_frbase.dart';
import 'package:bus_app/screens/search_route_screen/trip_card.dart';
import 'package:bus_app/services/firestore_route_service.dart';
import 'package:bus_app/services/route_service.dart';
import 'package:bus_app/widgets/route_summary_card.dart';
import 'package:bus_app/widgets/search_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:latlong2/latlong.dart';

class SearchRouteScreen extends StatefulWidget {
  const SearchRouteScreen({super.key});

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  final TextEditingController departController = TextEditingController();
  final TextEditingController arriveeController = TextEditingController();

  final firestoreService = FirestoreRouteService();
  final List<DirectionsRoute> apiRoutes = [];
  FirestoreRouteResultV1? firestoreResult;
  List<Map<String, dynamic>> nextTrips = [];

  late final RouteService routeService;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      throw Exception('Google Maps API key is missing in .env file');
    }
    routeService = RouteService(apiKey: apiKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      arriveeController.text = args;
    }
  }

  Future<void> searchRoutes() async {
    final depart = departController.text.trim();
    final arrivee = arriveeController.text.trim();

    if (depart.isEmpty || arrivee.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci de remplir les deux champs')),
      );
      return;
    }

    setState(() {
      isLoading = true;
      firestoreResult = null;
      apiRoutes.clear();
      nextTrips.clear();
    });

    try {
      final result = await _searchFirestoreTrips(depart, arrivee);
      if (result != null) {
        firestoreResult = result;
        nextTrips = await getNext3Trips(result.lineName, depart, arrivee);
      } else {
        final directions = await routeService.fetchBusRoutes(
          origin: depart,
          destination: arrivee,
        );
        apiRoutes.addAll(directions.routes);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString()}')),
      );
    }

    setState(() => isLoading = false);
  }

  /// Decode polyline string to list of LatLng coordinates
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> coordinates = [];
    int index = 0;
    int len = encoded.length;
    int lat = 0;
    int lng = 0;

    while (index < len) {
      int b;
      int shift = 0;
      int result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      coordinates.add(LatLng(lat / 1E5, lng / 1E5));
    }

    return coordinates;
  }

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // Earth's radius in meters
    
    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);
    
    double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    
    double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c;
  }

  double _toRadians(double degrees) {
    return degrees * (math.pi / 180);
  }

  /// Calculate total distance from polyline coordinates
  double _calculatePolylineDistance(List<LatLng> coordinates) {
    if (coordinates.length < 2) return 0.0;
    
    double totalDistance = 0.0;
    
    for (int i = 0; i < coordinates.length - 1; i++) {
      double lat1 = coordinates[i].latitude;
      double lon1 = coordinates[i].longitude;
      double lat2 = coordinates[i + 1].latitude;
      double lon2 = coordinates[i + 1].longitude;
      
      totalDistance += _calculateDistance(lat1, lon1, lat2, lon2);
    }
    
    return totalDistance;
  }

  /// Format distance to human readable string
  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.toStringAsFixed(0)} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  Future<FirestoreRouteResultV1?> _searchFirestoreTrips(String start, String end) async {
    final linesSnapshot = await FirebaseFirestore.instance.collection('tetouane').get();

    for (final lineDoc in linesSnapshot.docs) {
      final lineData = lineDoc.data();
      final polylines = (lineData['polyline'] ?? '').toString();
      final List<dynamic> trips = lineData['trips'] ?? [];

      for (final trip in trips) {
        if (trip is! Map<String, dynamic>) continue;

        final startAddress = (trip['startAddress'] ?? '').toString().toLowerCase();
        final endAddress = (trip['endAddress'] ?? '').toString().toLowerCase();
        

        if (startAddress.contains(start.toLowerCase()) && endAddress.contains(end.toLowerCase())) {
          final colorHex = lineData['color'] ?? '#007bff';
          final color = int.tryParse('FF${colorHex.replaceAll('#', '')}', radix: 16) ?? 0xFF007BFF;

          // Calculate distance from polyline if available
          String calculatedDistance = '0';
          if (polylines.isNotEmpty) {
            try {
              final coordinates = _decodePolyline(polylines);
              final distanceInMeters = _calculatePolylineDistance(coordinates);
              calculatedDistance = _formatDistance(distanceInMeters);
            } catch (e) {
              print('Error calculating polyline distance: $e');
              calculatedDistance = lineData['distance']?.toString() ?? '0';
            }
          } else {
            calculatedDistance = lineData['distance']?.toString() ?? '0';
          }


          return FirestoreRouteResultV1(
            polyline: _decodePolyline(polylines),
            stops: List<Map<String, dynamic>>.from(lineData['stops'] ?? []),
            lineName: lineData['route_name'] ?? '',
            colorValue: color,
            startTime: trip['startTime'] ?? '00:00:00',
            endTime: trip['endTime'] ?? '00:00:00',
            busDistance: calculatedDistance, startStopCoords: LatLng(0, 0), endStopCoords: LatLng(0, 0), distanceToStart: 0, distanceToEnd: 0, walkingTimeToStart: 0, walkingTimeToEnd: 0, startAddress: '', endAddress: '', startCoords: LatLng(0, 0), endCoords: LatLng(0, 0),
          );
        }
      }
    }

    return null;
  }

  /// Get estimated distance between two specific stops along the route
  String _getDistanceBetweenStops(String startLocation, String endLocation, List<LatLng> polylineCoordinates) {
    if (polylineCoordinates.isEmpty) return 'Distance inconnue';

    try {
      // Get coordinates for start and end locations
      // This is a simplified approach - in reality you might want to use geocoding
      // or match against actual stop coordinates stored in Firestore
      
      // For now, we'll calculate the total polyline distance
      final totalDistance = _calculatePolylineDistance(polylineCoordinates);
      return _formatDistance(totalDistance);
    } catch (e) {
      print('Error calculating distance between stops: $e');
      return 'Distance inconnue';
    }
  }

  Future<List<Map<String, dynamic>>> getNext3Trips(String lineName, String start, String end) async {
    final now = DateTime.now();
    final todayStr = DateFormat('yyyy-MM-dd').format(now);

    final linesSnapshot = await FirebaseFirestore.instance.collection('tetouane').get();

    for (final doc in linesSnapshot.docs) {
      final data = doc.data();
      if ((data['route_name'] ?? '').toString() != lineName) continue;

      final trips = data['trips'] ?? [];
      final List<Map<String, dynamic>> filtered = [];

      for (final trip in trips) {
        if (trip is! Map<String, dynamic>) continue;

        final startAddress = (trip['startAddress'] ?? '').toString().toLowerCase();
        final endAddress = (trip['endAddress'] ?? '').toString().toLowerCase();
        final timeStr = trip['startTime'];

        if (!startAddress.contains(start.toLowerCase()) || !endAddress.contains(end.toLowerCase()) || timeStr == null) continue;

        try {
          final fullDateTime = DateTime.parse('$todayStr $timeStr');
          if (fullDateTime.isAfter(now)) {
            trip['startDateTime'] = fullDateTime;
            
            // Add estimated distance for this specific trip segment
            final polylines = (data['polyline'] ?? '').toString();
            if (polylines.isNotEmpty) {
              final coordinates = _decodePolyline(polylines);
              trip['estimatedDistance'] = _getDistanceBetweenStops(start, end, coordinates);
            } else {
              trip['estimatedDistance'] = data['distance']?.toString() ?? 'Distance inconnue';
            }
            
            filtered.add(trip);
          }
        } catch (_) {}
      }

      filtered.sort((a, b) => (a['startDateTime'] as DateTime).compareTo(b['startDateTime'] as DateTime));
      return filtered.take(3).toList();
    }

    return [];
  }

  Future<void> setCurrentLocationAsDeparture() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception("Permission de localisation refusée");
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String fullAddress = "${place.street}, ${place.locality}";
        setState(() {
          departController.text = fullAddress;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de localisation : ${e.toString()}')),
      );
    }
  }

  String _calculerDureeParcourue(String startTime, String endTime) {
    try {
      final format = RegExp(r'^(\d{2}):(\d{2}):(\d{2})\$');
      if (format.hasMatch(startTime) && format.hasMatch(endTime)) {
        final startParts = startTime.split(':').map(int.parse).toList();
        final endParts = endTime.split(':').map(int.parse).toList();

        final start = DateTime(2023, 1, 1, startParts[0], startParts[1], startParts[2]);
        final end = DateTime(2023, 1, 1, endParts[0], endParts[1], endParts[2]);

        Duration diff = end.difference(start);
        if (diff.isNegative) {
          diff += const Duration(hours: 24);
        }
        return "${diff.inMinutes} min";
      }
    } catch (_) {}
    return "Durée inconnue";
  }

  @override
  void dispose() {
    departController.dispose();
    arriveeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Rechercher un itinéraire")),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          children: [
            RouteInputFields(
              departController: departController,
              arriveeController: arriveeController,
              onSearch: searchRoutes,
              onUseCurrentLocation: setCurrentLocationAsDeparture,
            ),
            if (isLoading) ...[
              const SizedBox(height: 24),
              const CircularProgressIndicator(),
            ],
            if (!isLoading && firestoreResult != null) ...[
              const SizedBox(height: 8),
              // Show route summary with calculated distance
              // Container(
              //   padding: const EdgeInsets.all(16),
              //   margin: const EdgeInsets.only(bottom: 16),
              //   decoration: BoxDecoration(
              //     color: Colors.blue.shade50,
              //     borderRadius: BorderRadius.circular(12),
              //     border: Border.all(color: Colors.blue.shade200),
              //   ),
              //   child: Column(
              //     crossAxisAlignment: CrossAxisAlignment.start,
              //     children: [
              //       Text(
              //         'Ligne: ${firestoreResult!.lineName}',
              //         style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              //       ),
              //       const SizedBox(height: 8),
              //       Text(
              //         'Distance estimée: ${firestoreResult!.distance}',
              //         style: const TextStyle(fontSize: 14, color: Colors.black87),
              //       ),
              //       Text(
              //         'Durée: ${_calculerDureeParcourue(firestoreResult!.startTime, firestoreResult!.endTime)}',
              //         style: const TextStyle(fontSize: 14, color: Colors.black87),
              //       ),
              //     ],
              //   ),
              // ),
              
              Expanded(
                child: ListView.builder(
                  itemCount: nextTrips.length > 3 ? 3 : nextTrips.length,
                  itemBuilder: (context, index) {
                    return TripCard(
                      route: firestoreResult!,
                      trip: nextTrips[index],
                    );
                  },
                ),
              ),
            ],
            if (!isLoading && firestoreResult == null && apiRoutes.isNotEmpty) ...[
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: apiRoutes.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: RouteSummaryCard(route: apiRoutes[index]),
                  ),
                ),
              ),
            ],
            if (!isLoading && firestoreResult == null && apiRoutes.isEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Aucun itinéraire trouvé.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}