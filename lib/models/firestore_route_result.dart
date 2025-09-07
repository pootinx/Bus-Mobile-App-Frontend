import 'package:latlong2/latlong.dart';


class FirestoreRouteResult {
  final List<LatLng> polyline;
  final List<Map<String, dynamic>> stops;
  final String lineName;
  final int colorValue;
  final String startTime;
  final String endTime;
  final String distance;

  FirestoreRouteResult({
    required this.polyline,
    required this.stops,
    required this.lineName,
    required this.colorValue,
    required this.startTime,
    required this.endTime,
    required this.distance,
  });
}


// import 'package:bus_app/models/directions_response.dart';
// import 'package:bus_app/models/firestore_stop.dart';
// import 'package:bus_app/models/firestore_trip.dart';

// class FirestoreRouteResult {
//   final List<LatLng> polyline;
//   final List<FirestoreStop> stops;
//   final List<FirestoreTrip> trips;
//   final String lineName;
//   final int colorValue;
//   final String startTime;
//   final String endTime;
//   final String distance;

//   FirestoreRouteResult({
//     required this.polyline,
//     required this.stops,
//     required this.trips,
//     required this.lineName,
//     required this.colorValue,
//     required this.startTime,
//     required this.endTime,
//     required this.distance,
//   });

//   factory FirestoreRouteResult.fromMap({
//     required String lineName,
//     required int colorValue,
//     required String startTime,
//     required String endTime,
//     required String distance,
//     required List<Map<String, dynamic>> stopDocs,
//     required List<Map<String, dynamic>> tripDocs,
//     required List<LatLng> decodedPolyline,
//   }) {
//     return FirestoreRouteResult(
//       polyline: decodedPolyline,
//       stops: stopDocs.map((e) => FirestoreStop.fromMap(e)).toList(),
//       trips: tripDocs.map((e) => FirestoreTrip.fromMap(e)).toList(),
//       lineName: lineName,
//       colorValue: colorValue,
//       startTime: startTime,
//       endTime: endTime,
//       distance: distance,
//     );
//   }
// }
