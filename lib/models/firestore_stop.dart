import 'package:latlong2/latlong.dart';

class FirestoreStop {
  final String name;
  final double lat;
  final double lon;
  final int order;
  final String lineId;

  FirestoreStop({
    required this.name,
    required this.lat,
    required this.lon,
    required this.order,
    required this.lineId,
  });

  factory FirestoreStop.fromMap(Map<String, dynamic> data) {
    return FirestoreStop(
      name: data['name'] ?? '',
      lat: (data['lat'] as num).toDouble(),
      lon: (data['lon'] as num).toDouble(),
      order: data['order'] ?? 0,
      lineId: data['line_id'] ?? '',
    );
  }

  LatLng get position => LatLng(lat, lon);

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'lat': lat,
      'lon': lon,
      'order': order,
      'line_id': lineId,
    };
  }
}
