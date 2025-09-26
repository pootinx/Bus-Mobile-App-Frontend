import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:bus_app/models/firestore_route_result.dart';
import 'package:bus_app/models/directions_response.dart';
import 'package:bus_app/services/firestore_route_service.dart';
import 'package:bus_app/services/route_service.dart';

class SearchRouteController {
  final TextEditingController departController = TextEditingController();
  final TextEditingController arriveeController = TextEditingController();

  final firestoreService = FirestoreRouteService();
  final List<DirectionsRoute> apiRoutes = [];
  FirestoreRouteResult? firestoreResult;
  List<Map<String, dynamic>> nextTrips = [];

  late RouteService routeService;
  bool isLoading = false;

  late BuildContext _context;
  late void Function(void Function()) _setState;

  void init(BuildContext context, void Function(void Function()) setState) {
    _context = context;
    _setState = setState;

    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
    routeService = RouteService(apiKey: apiKey);

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      arriveeController.text = args;
    }
  }

  void dispose() {
    departController.dispose();
    arriveeController.dispose();
  }

  Future<void> searchRoutes() async {
    final depart = departController.text.trim();
    final arrivee = arriveeController.text.trim();

    if (depart.isEmpty || arrivee.isEmpty) {
      ScaffoldMessenger.of(_context).showSnackBar(
        const SnackBar(content: Text('Merci de remplir les deux champs')),
      );
      return;
    }

    _setState(() {
      isLoading = true;
      firestoreResult = null;
      apiRoutes.clear();
      nextTrips.clear();
    });

    try {
      final result = await _searchFirestoreTrips(depart, arrivee);
      if (result != null) {
        firestoreResult = result;
        nextTrips = await _getNext3Trips(result.lineName, depart, arrivee);
      } else {
        final directions = await routeService.fetchBusRoutes(
          origin: depart,
          destination: arrivee,
        );
        apiRoutes.addAll(directions.routes);
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Erreur : ${e.toString()}')),
      );
    }

    _setState(() => isLoading = false);
  }

  Future<FirestoreRouteResult?> _searchFirestoreTrips(String start, String end) async {
    final linesSnapshot = await FirebaseFirestore.instance.collection('lines').get();

    for (final lineDoc in linesSnapshot.docs) {
      final lineRef = lineDoc.reference;
      final lineData = lineDoc.data();

      final tripsSnapshot = await lineRef.collection('trips').get();

      for (final tripDoc in tripsSnapshot.docs) {
        final trip = tripDoc.data();

        final hasStart = (trip['startAddress'] ?? '')
            .toString()
            .toLowerCase()
            .contains(start.toLowerCase());
        final hasEnd = (trip['endAddress'] ?? '')
            .toString()
            .toLowerCase()
            .contains(end.toLowerCase());

        if (hasStart && hasEnd) {
          final colorHex = lineData['color'] ?? '#007bff';
          final color = int.tryParse('FF${colorHex.replaceAll('#', '')}', radix: 16) ?? 0xFF007BFF;

          return FirestoreRouteResult(
            polyline: [],
            stops: [],
            lineName: lineData['route_name'] ?? '',
            colorValue: color,
            startTime: trip['startTime'] ?? '00:00:00',
            endTime: trip['endTime'] ?? '00:00:00',
            distance: lineData['distance']?.toString() ?? '0',
          );
        }
      }
    }

    return null;
  }
  

  Future<List<Map<String, dynamic>>> _getNext3Trips(String lineId, String start, String end) async {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);

    final snapshot = await FirebaseFirestore.instance
        .collection('lines')
        .doc(lineId)
        .collection('trips')
        .get();

    final filtered = snapshot.docs
        .map((doc) => doc.data())
        .where((trip) {
          final s = (trip['startAddress'] ?? '').toString().toLowerCase();
          final e = (trip['endAddress'] ?? '').toString().toLowerCase();
          final t = trip['startTime'] ?? '';
          if (!s.contains(start.toLowerCase()) || !e.contains(end.toLowerCase())) return false;
          try {
            return DateTime.parse('$today $t').isAfter(now);
          } catch (_) {
            return false;
          }
        })
        .toList();

    filtered.sort((a, b) =>
        DateTime.parse('$today ${a['startTime']}').compareTo(DateTime.parse('$today ${b['startTime']}')));

    return filtered.take(3).toList();
  }

  Future<void> setCurrentLocationAsDeparture() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception("Permission refusée");
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        _setState(() {
          departController.text = "${place.street}, ${place.locality}";
        });
      }
    } catch (e) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(_context).showSnackBar(
        SnackBar(content: Text('Erreur localisation : $e')),
      );
    }
  }
}

