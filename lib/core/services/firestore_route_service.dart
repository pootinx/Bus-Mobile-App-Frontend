import 'package:bus_app/shared/models/firestore_route_result.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart' as latlng;

class FirestoreRouteService {
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


Future<FirestoreRouteResult?> searchRoute(String start, String end) async {
  final linesSnapshot = await FirebaseFirestore.instance.collection('lines').get();

  for (final lineDoc in linesSnapshot.docs) {
    final lineRef = lineDoc.reference;
    final lineData = lineDoc.data();
    final lineName = lineData['route_name'] ?? '';

    // 🔽 Get the trips for this line
    final tripsSnapshot = await lineRef.collection('trips').get();

    for (final tripDoc in tripsSnapshot.docs) {
      final trip = tripDoc.data();

      final startAddress = (trip['startAddress'] ?? '').toString().toLowerCase();
      final endAddress = (trip['endAddress'] ?? '').toString().toLowerCase();

      final hasStart = startAddress.contains(start.toLowerCase());
      final hasEnd = endAddress.contains(end.toLowerCase());

      if (hasStart && hasEnd) {
        final colorHex = lineData['color'] ?? '#007bff';
        final color = int.tryParse('FF${colorHex.replaceAll('#', '')}', radix: 16) ?? 0xFF007BFF;

        return FirestoreRouteResult(
          polyline: [], // Or decodePolyline(lineData['polyline']) if exists
          stops: [],    // Not needed in this case
          lineName: lineName,
          colorValue: color,
          startTime: trip['startTime'] ?? '00:00:00',
          endTime: trip['endTime'] ?? '00:00:00',
          busDistance: lineData['distance']?.toString() ?? '0',
          startAddress: startAddress,
          endAddress: endAddress,
        );
      }
    }
  }

  return null;
}

  // Future<FirestoreRouteResult?> searchRoute(String start, String end) async {
  //   final querySnapshot = await FirebaseFirestore.instance.collection('lines').get();

  //   for (final doc in querySnapshot.docs) {
  //     final data = doc.data();
  //     final stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
  //     final stopNames = stops.map((s) => s['name'].toString().toLowerCase()).toList();

  //     final hasStart = stopNames.any((n) => n.contains(start.toLowerCase()));
  //     final hasEnd = stopNames.any((n) => n.contains(end.toLowerCase()));

  //     if (hasStart && hasEnd) {
  //       final polylineEncoded = data['polyline'];
  //       final colorHex = data['color'] ?? '#007bff';
  //       final color = int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16);

  //       final startTime = data['start_time'] ?? '00:00:00';
  //       final endTime = data['end_time'] ?? '00:00:00';
  //       final distance = data['distance']?.toString() ?? '0';

  //       return FirestoreRouteResult(
  //         polyline: decodePolyline(polylineEncoded),
  //         stops: stops,
  //         lineName: data['route_name'] ?? '',
  //         colorValue: color,
  //         startTime: startTime,
  //         endTime: endTime,
  //         distance: distance,
  //       );
  //     }
  //   }

  //   return null;
  // }
}
