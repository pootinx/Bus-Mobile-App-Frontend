import 'package:flutter/material.dart' hide Step;
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../models/directions_response.dart' hide LatLng, Polyline;

class CartScreen extends StatelessWidget {
  final DirectionsRoute route;

  const CartScreen({super.key, required this.route});

  List<LatLng> decodePolyline(String encoded) {
    final List<PointLatLng> points = PolylinePoints().decodePolyline(encoded);
    return points.map((p) => LatLng(p.latitude, p.longitude)).toList();
  }

  List<Polyline> buildPolylines(List<Step> steps) {
    List<Polyline> lines = [];

    for (var step in steps) {
      final List<LatLng> decoded = decodePolyline(step.polyline.points);
      final bool isTransit = step.travelMode == 'TRANSIT';

      final color = isTransit
          ? Color(int.parse('FF${step.transitDetails?.line.color.replaceAll("#", "")}', radix: 16))
          : Colors.blue;

      final stroke = isTransit ? 11.0 : 5.0;

      lines.add(Polyline(
        points: decoded,
        color: color,
        strokeWidth: stroke,
        pattern: isTransit
            ? const StrokePattern.solid()
            : StrokePattern.dashed(segments: [10.0, 9.0]),
      ));
    }

    return lines;
  }

  List<Marker> buildMarkers(List<Step> steps) {
    List<Marker> markers = [];

    for (var step in steps) {
      if (step.travelMode == 'TRANSIT' && step.transitDetails != null) {
        final departure = step.transitDetails!.departureStop;
        final line = step.transitDetails!.line;

        final LatLng stopLatLng = LatLng(
          departure.location.lat,
          departure.location.lng,
        );

        final String lineName = line.shortName;
        final String departureTime = step.transitDetails!.departureTime.text;

        markers.add(
          Marker(
            width: 110,
            height: 70,
            point: stopLatLng,
            child: SizedBox(
              height: 70,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.directions_bus, color: Colors.blue, size: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Bus $lineName',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                        Text(
                          departureTime,
                          style: const TextStyle(fontSize: 10, color: Colors.black87),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      if (step.steps != null) {
        markers.addAll(buildMarkers(step.steps!));
      }
    }

    return markers;
  }

  List<Marker> buildGlobalStartEndMarkers(Leg leg) {
    return [
      Marker(
        width: 60,
        height: 60,
        point: LatLng(leg.startLocation.lat, leg.startLocation.lng),
        child: SizedBox(
          height: 60,
          child: Column(
            children: [
              const Icon(Icons.flag_circle, color: Colors.green, size: 32),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                ),
                child: const Text(
                  'Départ',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
      Marker(
        width: 60,
        height: 60,
        point: LatLng(leg.endLocation.lat, leg.endLocation.lng),
        child: SizedBox(
          height: 60,
          child: Column(
            children: const [
              Icon(Icons.location_pin, color: Colors.red, size: 32),
              Text(
                'Arrivée',
                style: TextStyle(fontSize: 10),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = route.legs.first.steps;
    final polylines = buildPolylines(steps);
    final markers = buildMarkers(steps)
      ..addAll(buildGlobalStartEndMarkers(route.legs.first));

    return FutureBuilder<Marker?>(
      future: buildUserLocationMarker(),
      builder: (context, snapshot) {
        final updatedMarkers = [...markers];
        if (snapshot.hasData && snapshot.data != null) {
          updatedMarkers.add(snapshot.data!);
        }

        return Scaffold(
          appBar: AppBar(title: const Text("Carte de l’itinéraire")),
          body: SafeArea(
            bottom: false,
            child: FlutterMap(
              options: MapOptions(
                initialCameraFit: CameraFit.bounds(
                  bounds: LatLngBounds.fromPoints(
                    polylines.expand((p) => p.points).toList(),
                  ),
                  padding: const EdgeInsets.all(40),
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: ['a', 'b', 'c', 'd'],
                  tileProvider: NetworkTileProvider(),
                  userAgentPackageName: 'com.example.app',
                ),

                PolylineLayer(polylines: polylines),
                MarkerLayer(markers: updatedMarkers),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Marker?> buildUserLocationMarker() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        // ignore: deprecated_member_use
        desiredAccuracy: LocationAccuracy.high,
      );

      return Marker(
        width: 50,
        height: 50,
        point: LatLng(position.latitude, position.longitude),
        child: const Icon(Icons.person_pin_circle, size: 30, color: Colors.blue),
      );
    } catch (_) {
      return null;
    }
  }
}
