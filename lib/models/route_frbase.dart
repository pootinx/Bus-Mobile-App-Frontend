import 'package:latlong2/latlong.dart' show LatLng;

class FirestoreRouteResultV1 {
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

  FirestoreRouteResultV1({
    required this.polyline,
    required this.stops,
    required this.lineName,
    required this.colorValue,
    required this.startTime,
    required this.endTime,
    required this.busDistance,

    required this.startStopCoords,
    required this.endStopCoords,
    required this.startCoords,
    required this.endCoords,
    required this.distanceToStart,
    required this.distanceToEnd,
    required this.walkingTimeToStart,
    required this.walkingTimeToEnd,

    required this.startAddress,
    required this.endAddress,

  });

  
}


