import 'dart:async';
import 'package:bus_app/models/firestore_route_result.dart';
import 'package:bus_app/models/route_frbase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class RouteMapScreen extends StatefulWidget {
  final List<LatLng> polyline;
  final LatLng startPoint;
  final LatLng endPoint;
  final int colorValue;
  final List<BusStop>? stops;
  final bool isTransitRoute;
  final String? routeName;
  final String? departureTime;
  final String? arrivalTime;

  const RouteMapScreen({
    super.key,
    required this.polyline,
    required this.startPoint,
    required this.endPoint,
    this.colorValue = 0xFF007BFF,
    this.stops,
    this.isTransitRoute = false,
    this.routeName,
    this.departureTime,
    this.arrivalTime,
  });

  factory RouteMapScreen.fromFirestore(FirestoreRouteResultV1 result) {
    final safePolyline = result.polyline.isNotEmpty
        ? result.polyline
        : [const LatLng(0, 0)];

    return RouteMapScreen(
      polyline: result.polyline,
      startPoint: safePolyline.first,
      endPoint: safePolyline.last,
      colorValue: result.colorValue,
    );
  }

  factory RouteMapScreen.fromApi(Map<String, dynamic> apiData) {
    final List<LatLng> points = _decodePolyline(apiData['polyline']);
    return RouteMapScreen(
      polyline: points,
      startPoint: points.first,
      endPoint: points.last,
      colorValue: 0xFF007BFF,
      isTransitRoute: apiData['isTransit'] ?? false,
      routeName: apiData['routeName'],
      departureTime: apiData['departureTime'],
      arrivalTime: apiData['arrivalTime'],
    );
  }

  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
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

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  late final MapController _mapController;
  Marker? _userLocationMarker;
  StreamSubscription<Position>? _positionStream;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initLocationUpdates();
  }

  void _initLocationUpdates() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever ||
        permission == LocationPermission.denied) return;

    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((position) {
      final marker = Marker(
        point: LatLng(position.latitude, position.longitude),
        width: 40,
        height: 40,
        child: const Icon(Icons.person_pin_circle, size: 28, color: Colors.blue),
      );
      setState(() {
        _userLocationMarker = marker;
      });
    });
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  List<Polyline> _buildPolylines() {
    final color = Color(widget.colorValue);
    final strokeWidth = widget.isTransitRoute ? 8.0 : 5.0;
    return [
      Polyline(
        points: widget.polyline,
        strokeWidth: strokeWidth,
        color: color,
      ),
    ];
  }

  List<Marker> _buildMarkers() {
    List<Marker> markers = [];

    // Start marker
    markers.add(
      Marker(
        point: widget.startPoint,
        width: 70,
        height: 80,
        child: Column(
          children: [
            const Icon(Icons.flag_circle, color: Colors.green, size: 36),
            _buildMarkerLabel('Départ', widget.departureTime, Colors.green),
          ],
        ),
      ),
    );

    // End marker
    markers.add(
      Marker(
        point: widget.endPoint,
        width: 70,
        height: 80,
        child: Column(
          children: [
            const Icon(Icons.location_pin, color: Colors.red, size: 36),
            _buildMarkerLabel('Arrivée', widget.arrivalTime, Colors.red),
          ],
        ),
      ),
    );

    // Stops
    if (widget.stops != null) {
      for (final stop in widget.stops!) {
        markers.add(
          Marker(
            point: LatLng(stop.latitude, stop.longitude),
            width: 120,
            height: 80,
            child: Column(
              children: [
                Icon(
                  widget.isTransitRoute ? Icons.directions_bus : Icons.place,
                  color: Color(widget.colorValue),
                  size: 28,
                ),
                _buildStopLabel(stop),
              ],
            ),
          ),
        );
      }
    }

    // User location
    if (_userLocationMarker != null) {
      markers.add(_userLocationMarker!);
    }

    return markers;
  }

  Widget _buildMarkerLabel(String title, String? time, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (time != null)
            Text(
              time,
              style: const TextStyle(fontSize: 9, color: Colors.black87),
            ),
        ],
      ),
    );
  }

  Widget _buildStopLabel(BusStop stop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: Column(
        children: [
          if (widget.routeName != null)
            Text(
              widget.routeName!,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(widget.colorValue),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            stop.name,
            style: const TextStyle(fontSize: 9, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (stop.arrivalTime != null)
            Text(
              stop.arrivalTime!,
              style: const TextStyle(fontSize: 8, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final polylines = _buildPolylines();
    final markers = _buildMarkers();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.routeName != null ? 'Trajet ${widget.routeName}' : 'Trajet sur la carte',
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SafeArea(
        child: FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(widget.polyline),
              padding: const EdgeInsets.all(50),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: ['a', 'b', 'c', 'd'],
              tileProvider: NetworkTileProvider(),
            ),
            PolylineLayer(polylines: polylines),
            MarkerLayer(markers: markers),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final position = await Geolocator.getCurrentPosition();
          _mapController.move(LatLng(position.latitude, position.longitude), 17);
        },
        backgroundColor: Color(widget.colorValue),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}

class BusStop {
  final String name;
  final double latitude;
  final double longitude;
  final String? arrivalTime;
  final String? departureTime;

  const BusStop({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.arrivalTime,
    this.departureTime,
  });

  factory BusStop.fromMap(Map<String, dynamic> map) {
    return BusStop(
      name: map['name'] ?? '',
      latitude: map['latitude']?.toDouble() ?? 0.0,
      longitude: map['longitude']?.toDouble() ?? 0.0,
      arrivalTime: map['arrivalTime'],
      departureTime: map['departureTime'],
    );
  }
}
