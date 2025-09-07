import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class BusLineDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> lineData;

  const BusLineDetailsScreen({super.key, required this.lineData});

  @override
  State<BusLineDetailsScreen> createState() => _BusLineDetailsScreenState();
}

class _BusLineDetailsScreenState extends State<BusLineDetailsScreen> with TickerProviderStateMixin {
  List<LatLng> polylinePoints = [];
  late Color lineColor;
  List<Map<String, dynamic>> stops = [];
  LatLng? currentLocation;
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();
  bool _isLocationEnabled = false;
  bool _isFollowingLocation = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  @override
  void initState() {
    super.initState();
    
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fabAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    final data = widget.lineData;
    polylinePoints = decodePolyline(data['polyline']);
    stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);

    if (data['color_final'] != null && data['color_final'] is Color) {
      lineColor = data['color_final'];
    } else if (data['color'] != null && data['color'] is String) {
      lineColor = _hexToColor(data['color']);
    } else {
      lineColor = Colors.blue;
    }

    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return;
    }

    setState(() {
      _isLocationEnabled = true;
    });

    _fabAnimationController.forward();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // Update every 5 meters
    );

    _positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen((Position position) {
      setState(() {
        currentLocation = LatLng(position.latitude, position.longitude);
      });

      if (_isFollowingLocation) {
        _mapController.move(currentLocation!, _mapController.camera.zoom);
      }
    });
  }

  List<Marker> _buildStopMarkers() {
    List<Marker> markers = [];
    
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final lat = stop['latitude'] ?? 0.0;
      final lng = stop['longitude'] ?? 0.0;
      
      // Skip if coordinates are not available
      if (lat == 0.0 && lng == 0.0) continue;
      
      final isFirst = i == 0;
      final isLast = i == stops.length - 1;
      
      markers.add(
        Marker(
          point: LatLng(lat, lng),
          width: isFirst || isLast ? 40 : 24,
          height: isFirst || isLast ? 40 : 24,
          child: Container(
            decoration: BoxDecoration(
              color: isFirst || isLast ? lineColor : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: lineColor,
                width: isFirst || isLast ? 3 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isFirst || isLast
                ? Icon(
                    isFirst ? Icons.place : Icons.flag,
                    color: Colors.white,
                    size: isFirst || isLast ? 20 : 12,
                  )
                : Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: lineColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
          ),
        ),
      );
    }
    
    // Add departure and arrival markers at the start and end of polyline
    if (polylinePoints.isNotEmpty) {
      // Departure marker
      markers.add(
        Marker(
          point: polylinePoints.first,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.green.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.flag_circle,
              color: Colors.white,
              size: 23,
            ),
          ),
        ),
      );
      
      // Arrival marker
      markers.add(
        Marker(
          point: polylinePoints.last,
          width: 40,
          height: 40,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.location_pin,
              color: Colors.white,
              size: 23,
            ),
          ),
        ),
      );
    }
    
    return markers;
  }

  void _toggleLocationFollow() {
    setState(() {
      _isFollowingLocation = !_isFollowingLocation;
    });

    if (_isFollowingLocation && currentLocation != null) {
      _mapController.move(currentLocation!, 16.0);
    }
  }

  void _centerOnMyLocation() {
    if (currentLocation != null) {
      _mapController.move(currentLocation!, 16.0);
      setState(() {
        _isFollowingLocation = true;
      });
    }
  }

  void _centerOnRoute() {
    if (polylinePoints.isNotEmpty) {
      final bounds = _calculateBounds(polylinePoints);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(50),
        ),
      );
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final point in points) {
      minLat = minLat < point.latitude ? minLat : point.latitude;
      maxLat = maxLat > point.latitude ? maxLat : point.latitude;
      minLng = minLng < point.longitude ? minLng : point.longitude;
      maxLng = maxLng > point.longitude ? maxLng : point.longitude;
    }

    return LatLngBounds(
      LatLng(minLat, minLng),
      LatLng(maxLat, maxLng),
    );
  }

  List<LatLng> decodePolyline(String encoded) {
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

  Color _hexToColor(String hex) {
    hex = hex.replaceAll("#", "");
    if (hex.length == 6) hex = "FF$hex";
    return Color(int.parse(hex, radix: 16));
  }

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
          if (currentLocation != null)
            IconButton(
              icon: const Icon(Icons.my_location),
              onPressed: _centerOnMyLocation,
              tooltip: 'Ma position',
            ),
          IconButton(
            icon: const Icon(Icons.route),
            onPressed: _centerOnRoute,
            tooltip: 'Centrer sur la ligne',
          ),
        ],
      ),
      body: Column(
        children: [
          // Enhanced Map Container
          Container(
            height: 280,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: polylinePoints.isNotEmpty
                        ? polylinePoints.first
                        : const LatLng(34.02, -6.83),
                    initialZoom: 13,
                    maxZoom: 18,
                    minZoom: 10,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: ['a', 'b', 'c', 'd'],
                      tileProvider: NetworkTileProvider(),
                      userAgentPackageName: 'com.example.app',
                    ),
                    PolylineLayer(
                      polylines: isDotted
                          ? List.generate(
                              (polylinePoints.length / 2).floor(),
                              (i) => Polyline(
                                points: polylinePoints.skip(i * 2).take(2).toList(),
                                strokeWidth: 5,
                                color: lineColor,
                              ),
                            )
                          : [
                              Polyline(
                                points: polylinePoints,
                                strokeWidth: 5,
                                color: lineColor,
                              ),
                            ],
                    ),
                    // Stop markers with departure and arrival icons
                    MarkerLayer(
                      markers: _buildStopMarkers(),
                    ),
                    // User location marker with enhanced design
                    if (currentLocation != null)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: currentLocation!,
                            width: 50,
                            height: 50,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Pulsing circle animation
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 30,
                                  height: 30,
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.blue,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.5),
                                        blurRadius: 10,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.person_pin_circle,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                // Location controls
                // y
              ],
            ),
          ),
          // Enhanced Route Info
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [lineColor, lineColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.route,
                      color: Colors.white,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "$start → $end",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${stops.length} arrêts",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 20),
                    Icon(
                      isDotted ? Icons.more_horiz : Icons.timeline,
                      color: Colors.white70,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isDotted ? "Intermittente" : "Continue",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Enhanced Stops List
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

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: InkWell(
                      onTap: () {
                        // Handle stop tap - could show more info or navigate
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Enhanced timeline indicator
                            SizedBox(
                              width: 30,
                              child: Column(
                                children: [
                                  if (!isFirst)
                                    Container(
                                      height: 20,
                                      width: 3,
                                      decoration: BoxDecoration(
                                        color: lineColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  Container(
                                    width: 16,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: isFirst || isLast ? lineColor : Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: lineColor,
                                        width: 2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: lineColor.withOpacity(0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: isFirst || isLast
                                        ? Icon(
                                            isFirst ? Icons.play_arrow : Icons.stop,
                                            color: Colors.white,
                                            size: 10,
                                          )
                                        : null,
                                  ),
                                  if (!isLast)
                                    Container(
                                      height: 40,
                                      width: 3,
                                      decoration: BoxDecoration(
                                        color: lineColor.withOpacity(0.3),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: isFirst || isLast 
                                          ? FontWeight.bold 
                                          : FontWeight.normal,
                                      color: isFirst || isLast 
                                          ? lineColor 
                                          : Colors.black87,
                                    ),
                                  ),
                                  if (isFirst || isLast)
                                    Text(
                                      isFirst ? "Point de départ" : "Terminus",
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: lineColor.withOpacity(0.7),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}