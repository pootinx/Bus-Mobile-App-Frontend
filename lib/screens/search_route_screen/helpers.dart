import 'package:latlong2/latlong.dart';

class LatLng {
  final double latitude;
  final double longitude;

  LatLng(this.latitude, this.longitude);
}

String calculerDureeParcourue(String startTime, String endTime) {
  try {
    final partsStart = startTime.split(':').map(int.parse).toList();
    final partsEnd = endTime.split(':').map(int.parse).toList();

    final start = DateTime(2023, 1, 1, partsStart[0], partsStart[1], partsStart[2]);
    final end = DateTime(2023, 1, 1, partsEnd[0], partsEnd[1], partsEnd[2]);

    Duration diff = end.difference(start);
    if (diff.isNegative) diff += const Duration(hours: 24);

    return "${diff.inMinutes} min";
  } catch (_) {
    return "Durée inconnue";
  }
}


List<LatLng> decodePolyline(String encoded) {
  List<LatLng> points = [];
  int index = 0, lat = 0, lng = 0;

  while (index < encoded.length) {
    int b, shift = 0, result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1F) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    points.add(LatLng(lat / 1e5, lng / 1e5));
  }

  return points;
}

