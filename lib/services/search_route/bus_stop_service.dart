// // lib/services/search_route/bus_stop_service.dart
// import 'dart:convert';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:http/http.dart' as http;
// import 'package:latlong2/latlong.dart';
// import 'package:bus_app/models/bus_stop.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';

// class BusStopService {
//   static List<QueryDocumentSnapshot>? _cachedLines;
//   static DateTime? _lastFetch;

//   /// Recherche rapide d'un couple départ / arrivée dans une même ligne
//   static Future<Map<String, dynamic>?> findStopsInSameLineByNames(String depart, String arrivee) async {
//     final depClean = depart.trim().toLowerCase();
//     final arrClean = arrivee.trim().toLowerCase();

//     if (_cachedLines == null || DateTime.now().difference(_lastFetch ?? DateTime(2000)).inMinutes > 5) {
//       final snapshot = await FirebaseFirestore.instance.collection('lines').get();
//       _cachedLines = snapshot.docs;
//       _lastFetch = DateTime.now();
//       print("📦 Lignes chargées depuis Firestore: ${_cachedLines!.length}");
//     } else {
//       print("✅ Lignes chargées depuis le cache: ${_cachedLines!.length}");
//     }

//     for (final lineDoc in _cachedLines!) {
//       final stopsSnap = await lineDoc.reference.collection('stops').get();

//       BusStop? depStop;
//       BusStop? arrStop;

//       for (final doc in stopsSnap.docs) {
//         final data = doc.data() as Map<String, dynamic>;
//         final name = (data['name'] ?? '').toString().toLowerCase();
//         final lat = (data['latitude'] ?? data['lat'])?.toDouble();
//         final lon = (data['longitude'] ?? data['lon'])?.toDouble();
//         if (name.isEmpty || lat == null || lon == null) continue;

//         if (depStop == null && _match(depClean, name)) {
//           depStop = BusStop(name: name, latitude: lat, longitude: lon, address: data['address']);
//         }
//         if (arrStop == null && _match(arrClean, name)) {
//           arrStop = BusStop(name: name, latitude: lat, longitude: lon, address: data['address']);
//         }

//         if (depStop != null && arrStop != null) {
//           print("✅ Match trouvé dans ligne: ${lineDoc.id}");
//           return {
//             'lineId': lineDoc.id,
//             'departure': depStop,
//             'arrival': arrStop,
//           };
//         }
//       }
//     }

//     print("❌ Aucun match trouvé dans les lignes locales, tentative via Google Directions API...");
//     return await _fallbackWithGoogleRoute(depart, arrivee);
//   }

//   static bool _match(String query, String name) {
//     return name == query || name.contains(query) || query.contains(name);
//   }

//   static Future<Map<String, dynamic>?> _fallbackWithGoogleRoute(String depart, String arrivee) async {
//     try {
//       final key = dotenv.env['GOOGLE_MAPS_API_KEY'];
//       final url = Uri.parse(
//         'https://maps.googleapis.com/maps/api/directions/json?origin=${Uri.encodeComponent(depart)}&destination=${Uri.encodeComponent(arrivee)}&mode=transit&key=$key',
//       );

//       final response = await http.get(url);
//       final json = jsonDecode(response.body);

//       if (json['status'] == 'OK' && json['routes'] != null && json['routes'].isNotEmpty) {
//         final leg = json['routes'][0]['legs'][0];
//         final startLoc = leg['start_location'];
//         final endLoc = leg['end_location'];

//         final depStop = BusStop(
//           name: depart,
//           latitude: startLoc['lat'],
//           longitude: startLoc['lng'],
//           address: leg['start_address'],
//         );

//         final arrStop = BusStop(
//           name: arrivee,
//           latitude: endLoc['lat'],
//           longitude: endLoc['lng'],
//           address: leg['end_address'],
//         );

//         print("✅ Itinéraire Google trouvé entre $depart et $arrivee");
//         return {
//           'lineId': null,
//           'departure': depStop,
//           'arrival': arrStop,
//         };
//       }
//     } catch (e) {
//       print("❌ Erreur lors de l'appel à Google Directions API : $e");
//     }

//     return null;
//   }
// } 
