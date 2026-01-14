// import 'package:bus_app/shared/models/firestore_route_result.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:latlong2/latlong.dart';


// class SearchService {
//   static Future<List<FirestoreRouteResult>> searchNext3Trips(String start, String end) async {
//     final now = DateTime.now().toUtc().add(const Duration(hours: 1));
//     final nowMin = now.hour * 60 + now.minute;

//     final trips = <Map<String, dynamic>>[];
//     final linesSnap = await FirebaseFirestore.instance.collection('lines').get();

//     await Future.wait(linesSnap.docs.map((doc) async {
//       await _processLineForSearch(doc, start, end, nowMin, trips);
//     }));

//     trips.sort((a, b) => a['diff'].compareTo(b['diff']));
//     return trips.take(3).map(_entryToResult).toList();
//   }

//   static Future<void> _processLineForSearch(QueryDocumentSnapshot doc, String start, String end, int nowMin, List<Map<String, dynamic>> list) async {
//     final line = doc.data() as Map<String, dynamic>;
//     final tripsSnap = await doc.reference.collection('trips').get();
//     final stopsSnap = await doc.reference.collection('stops').get();

//     final stops = stopsSnap.docs.map((d) => d.data() as Map<String, dynamic>).toList();
//     final pairs = _findMatchingStopsInLine(stops, start, end);
//     if (pairs.isEmpty) return;

//     for (final tripDoc in tripsSnap.docs) {
//       final trip = tripDoc.data() as Map<String, dynamic>;
//       final tripMin = _timeToMin(trip['startTime'] ?? '');
//       if (tripMin == null) continue;

//       int diff = tripMin - nowMin;
//       if (diff < 0) diff += 1440;
//       list.add({'diff': diff, 'trip': trip, 'line': line, 'stops': stops});
//     }
//   }

//   static List<Map<String, dynamic>> _findMatchingStopsInLine(List<Map<String, dynamic>> stops, String start, String end) {
//     final res = <Map<String, dynamic>>[];
//     for (int i = 0; i < stops.length; i++) {
//       final nameStart = (stops[i]['name'] ?? '').toString().toLowerCase();
//       if (!_match(nameStart, start)) continue;
//       for (int j = i + 1; j < stops.length; j++) {
//         final nameEnd = (stops[j]['name'] ?? '').toString().toLowerCase();
//         if (_match(nameEnd, end)) {
//           res.add({'startIndex': i, 'endIndex': j});
//           break;
//         }
//       }
//     }
//     return res;
//   }

//   static bool _match(String stop, String search) {
//     stop = stop.trim();
//     search = search.toLowerCase().trim();
//     if (stop == search) return true;
//     if (stop.contains(search) || search.contains(stop)) return true;
//     final sw = search.split(' ');
//     for (final w in sw) {
//       if (w.length > 2 && stop.contains(w)) return true;
//     }
//     return false;
//   }

//   static int? _timeToMin(String t) {
//     final parts = t.split(':');
//     if (parts.length < 2) return null;
//     final h = int.tryParse(parts[0]) ?? 0;
//     final m = int.tryParse(parts[1]) ?? 0;
//     return h * 60 + m;
//   }

//   static List<LatLng> decodePolyline(String enc) {
//     final List<LatLng> pts = [];
//     int idx = 0, lat = 0, lng = 0;
//     while (idx < enc.length) {
//       int b, shift = 0, res = 0;
//       do {
//         b = enc.codeUnitAt(idx++) - 63;
//         res |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlat = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       lat += dlat;
//       shift = 0;
//       res = 0;
//       do {
//         b = enc.codeUnitAt(idx++) - 63;
//         res |= (b & 0x1F) << shift;
//         shift += 5;
//       } while (b >= 0x20);
//       int dlng = (res & 1) != 0 ? ~(res >> 1) : (res >> 1);
//       lng += dlng;
//       pts.add(LatLng(lat / 1e5, lng / 1e5));
//     }
//     return pts;
//   }

//   static FirestoreRouteResult _entryToResult(Map<String, dynamic> e) {
//     final trip = e['trip'] as Map<String, dynamic>;
//     final line = e['line'] as Map<String, dynamic>;
//     final poly = decodePolyline(line['polyline'] ?? '');
//     final color = int.parse('FF${(line['color'] ?? '#007bff').replaceAll('#', '')}', radix: 16);
//     return FirestoreRouteResult(
//       polyline: poly,
//       stops: e['stops'] as List<Map<String, dynamic>>,
//       lineName: line['route_name'] ?? '',
//       colorValue: color,
//       startTime: trip['startTime'] ?? '00:00:00',
//       endTime: trip['endTime'] ?? '00:00:00',
//       distance: trip['distance']?.toString() ?? '0',
//     );
//   }
// }
