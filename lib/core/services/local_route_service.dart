import 'package:cloud_firestore/cloud_firestore.dart';

class LocalRouteResult {
  final String lineName;
  final String polyline;
  final List<Map<String, dynamic>> stops;
  final String colorHex;
  final Map<String, dynamic> rawLine;

  LocalRouteResult({
    required this.lineName,
    required this.polyline,
    required this.stops,
    required this.colorHex,
    required this.rawLine,
  });
}

class LocalRouteService {
  Future<LocalRouteResult?> searchRoute(String start, String end) async {
    final querySnapshot = await FirebaseFirestore.instance.collection('bus_lines').get();
    final startLower = start.toLowerCase();
    final endLower = end.toLowerCase();

    for (final doc in querySnapshot.docs) {
      final data = doc.data();
      final stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);
      final stopNames = stops.map((s) => s['name'].toString().toLowerCase()).toList();

      final hasStart = stopNames.any((n) => n.contains(startLower));
      final hasEnd = stopNames.any((n) => n.contains(endLower));

      if (hasStart && hasEnd) {
        return LocalRouteResult(
          lineName: data['route_name'] ?? '',
          polyline: data['polyline'] ?? '',
          stops: stops,
          colorHex: data['color'] ?? '#007bff',
          rawLine: data,
        );
      }
    }

    return null;
  }
}
