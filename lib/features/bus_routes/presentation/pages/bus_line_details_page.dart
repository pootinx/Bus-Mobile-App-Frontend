
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class BusLineDetailsPage extends StatefulWidget {
  final Map<String, dynamic> lineData;

  const BusLineDetailsPage({super.key, required this.lineData});

  @override
  State<BusLineDetailsPage> createState() => _BusLineDetailsPageState();
}

class _BusLineDetailsPageState extends State<BusLineDetailsPage> {
  // State for Google Maps
  GoogleMapController? _mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  LatLng? _initialCameraPosition;

  // Existing state
  late Color lineColor;
  List<Map<String, dynamic>> stops = [];
  LatLng? currentLocation;
  StreamSubscription<Position>? _positionStream;
  bool _isFollowingLocation = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = widget.lineData;
    final List<LatLng> polylinePoints = _decodePolyline(data['polyline']);
    stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);

    // Determine line color (same as before)
    if (data['color_final'] != null && data['color_final'] is Color) {
      lineColor = data['color_final'];
    } else if (data['color'] != null && data['color'] is String) {
      lineColor = _hexToColor(data['color']);
    } else {
      lineColor = Colors.blue;
    }

    await _setupGoogleMapData(polylinePoints, stops);
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  // --- Location Methods (adapted for Google Maps) ---

  Future<void> _initializeLocation() async {
    if (await Geolocator.isLocationServiceEnabled()) {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return;
      }
      _startLocationTracking();
    }
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10);
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) {
        setState(() {
          currentLocation = LatLng(position.latitude, position.longitude);
          _updateUserMarker();
        });
        if (_isFollowingLocation) {
          _mapController?.animateCamera(CameraUpdate.newLatLng(currentLocation!));
        }
      }
    });
  }

  void _updateUserMarker() {
    if (currentLocation != null) {
      _markers.removeWhere((m) => m.markerId.value == 'user_location');
      _markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: currentLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: const InfoWindow(title: 'Ma Position'),
        ),
      );
    }
  }
  
  // --- Map Setup and Control Methods for Google Maps ---

  Future<BitmapDescriptor> _createDotMarkerBitmap(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 20.0;

    canvas.drawCircle(
      const Offset(radius, radius),
      radius,
      paint,
    );

    paint.color = Colors.white;
    canvas.drawCircle(
      const Offset(radius, radius),
      radius - 5,
      paint,
    );

    final img = await pictureRecorder.endRecording().toImage(radius.toInt() * 2, radius.toInt() * 2);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<void> _setupGoogleMapData(List<LatLng> polylinePoints, List<Map<String, dynamic>> stops) async {
    // 1. Create Polyline
    _polylines.add(Polyline(
      polylineId: PolylineId(widget.lineData['route_name'] ?? 'line'),
      points: polylinePoints,
      color: lineColor,
      width: 5,
    ));

    // 2. Create Markers for stops
    final BitmapDescriptor stopIcon = await _createDotMarkerBitmap(lineColor);

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final lat = stop['latitude'] ?? 0.0;
      final lng = stop['longitude'] ?? 0.0;

      if (lat == 0.0 && lng == 0.0) continue;

      _markers.add(Marker(
        markerId: MarkerId(stop['name'] ?? 'stop_$i'),
        position: LatLng(lat, lng),
        infoWindow: InfoWindow(title: stop['name']),
        icon: stopIcon,
      ));
    }

    // 3. Set Initial Camera Position
    if (polylinePoints.isNotEmpty) {
      _initialCameraPosition = _calculateCenter(polylinePoints);
    } else if (stops.isNotEmpty) {
      _initialCameraPosition = LatLng(stops.first['latitude'], stops.first['longitude']);
    } else {
      _initialCameraPosition = const LatLng(34.02, -6.83); // Fallback
    }

    if (mounted) {
      setState(() {});
    }
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerOnRoute();
  }

  void _centerOnRoute() {
    if (_mapController == null || _polylines.isEmpty) return;
    final bounds = _calculateBounds(_polylines.first.points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
  }

  void _centerOnMyLocation() {
    if (currentLocation != null) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(currentLocation!, 15));
      setState(() { _isFollowingLocation = true; });
    }
  }

  // --- Helper and Utility Functions ---

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)); lat += dlat;
      shift = 0; result = 0;
      do { b = encoded.codeUnitAt(index++) - 63; result |= (b & 0x1F) << shift; shift += 5; } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1)); lng += dlng;
      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }
  
  LatLngBounds _calculateBounds(List<LatLng> points) {
    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    return LatLngBounds(
      southwest: LatLng(lats.reduce((a, b) => a < b ? a : b), lngs.reduce((a, b) => a < b ? a : b)),
      northeast: LatLng(lats.reduce((a, b) => a > b ? a : b), lngs.reduce((a, b) => a > b ? a : b)),
    );
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(34.02, -6.83);
    final bounds = _calculateBounds(points);
    return LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

  // --- Build Method ---

  @override
  Widget build(BuildContext context) {
    final routeName = widget.lineData['route_name'] ?? 'Inconnue';
    final isDotted = widget.lineData['type'] == 'intermittente';
    final start = stops.isNotEmpty ? stops.first['name'] ?? '...' : '...';
    final end = stops.isNotEmpty ? stops.last['name'] ?? '...' : '...';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Ligne $routeName"),
        backgroundColor: lineColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (currentLocation != null) IconButton(icon: const Icon(Icons.my_location), onPressed: _centerOnMyLocation, tooltip: 'Ma position'),
          IconButton(icon: const Icon(Icons.route), onPressed: _centerOnRoute, tooltip: 'Centrer sur la ligne'),
        ],
      ),
      body: Column(
        children: [
          // Map Container - Now using GoogleMap
          SizedBox(
            height: 280,
            child: GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: CameraPosition(
                target: _initialCameraPosition ?? const LatLng(34.02, -6.83),
                zoom: 12,
              ),
              onMapCreated: _onMapCreated,
              polylines: _polylines,
              markers: _markers,
              myLocationEnabled: false, // Custom location marker is used
              myLocationButtonEnabled: false,
              zoomControlsEnabled: true,
            ),
          ),

          // Route Info Panel (UI remains the same)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lineColor, lineColor.withOpacity(0.8)],
                begin: Alignment.topLeft, end: Alignment.bottomRight
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.route, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text("$start → $end", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.location_on, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text("${stops.length} arrêts", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(width: 20),
                  Icon(isDotted ? Icons.more_horiz : Icons.timeline, color: Colors.white70, size: 16),
                  const SizedBox(width: 4),
                  Text(isDotted ? "Intermittente" : "Continue", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                ]),
              ],
            ),
          ),

          // Stops List (UI remains the same)
          Expanded(
            child: Container(
              color: Colors.white,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: stops.length,
                itemBuilder: (context, index) {
                  final stop = stops[index];
                  final name = stop['name'] ?? 'Inconnu';
                  final isFirst = index == 0;
                  final isLast = index == stops.length - 1;

                  return ListTile(
                    leading: _buildStopIndicator(index, stops.length, lineColor),
                    title: Text(
                      name,
                      style: TextStyle(
                        fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.normal,
                        color: isFirst || isLast ? lineColor : Colors.black87,
                      ),
                    ),
                    subtitle: Text(isFirst ? "Point de départ" : isLast ? "Terminus" : "", style: TextStyle(color: Colors.grey.shade600)),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper for drawing the list view timeline
  Widget _buildStopIndicator(int index, int stopCount, Color color) {
    return SizedBox(
      width: 30,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (index > 0) Expanded(child: Container(width: 2, color: color.withOpacity(0.3))),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              color: (index == 0 || index == stopCount -1) ? color : Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              (index == 0) ? Icons.play_arrow : (index == stopCount -1) ? Icons.stop : Icons.circle,
              color: (index == 0 || index == stopCount -1) ? Colors.white : color,
              size: 14,
            ),
          ),
          if (index < stopCount - 1) Expanded(child: Container(width: 2, color: color.withOpacity(0.3))),
        ],
      ),
    );
  }
}
