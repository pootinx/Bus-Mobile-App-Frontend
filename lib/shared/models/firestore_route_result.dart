import 'package:latlong2/latlong.dart' show LatLng;

class FirestoreRouteResult {
  final List<LatLng> polyline;
  final List<Map<String, dynamic>> stops;
  final String lineName;
  final int colorValue;
  final String startTime;
  final String endTime;
  final String busDistance;
  final String startAddress;
  final String endAddress;


  // 🆕 New fields
  final LatLng startStopCoords;
  final LatLng endStopCoords;
  final LatLng startCoords;
  final LatLng endCoords;
  final double distanceToStart;
  final double distanceToEnd;
  final int walkingTimeToStart;
  final int walkingTimeToEnd;

  FirestoreRouteResult({
    required this.polyline,
    required this.stops,
    required this.lineName,
    required this.colorValue,
    required this.startTime,
    required this.endTime,
    this.busDistance = '0',
    this.startStopCoords = const LatLng(0, 0),
    this.endStopCoords = const LatLng(0, 0),
    this.startCoords = const LatLng(0, 0),
    this.endCoords = const LatLng(0, 0),
    this.distanceToStart = 0.0,
    this.distanceToEnd = 0.0,
    this.walkingTimeToStart = 0,
    this.walkingTimeToEnd = 0,
    required this.startAddress,
    required this.endAddress,
  });

  
}


