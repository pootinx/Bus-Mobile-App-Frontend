import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class BusLineDetailsScreen extends StatefulWidget {
  const BusLineDetailsScreen({super.key});

  @override
  State<BusLineDetailsScreen> createState() => _BusLineDetailsScreenState();
}

class _BusLineDetailsScreenState extends State<BusLineDetailsScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? lineData;
  bool _isLoading = true;
  String? _error;

  List<LatLng> polylinePoints = [];
  Color lineColor = Colors.blue; // Default color
  List<Map<String, dynamic>> stops = [];
  LatLng? currentLocation;
  StreamSubscription<Position>? _positionStream;
  final MapController _mapController = MapController();
  bool _isLocationEnabled = false;
  bool _isFollowingLocation = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabAnimation;

  int? lineId;
  String? lineName;

  @override
  void initState() {
    super.initState();

    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _fabAnimationController,
      curve: Curves.easeInOut,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        lineId = args['lineId'];
        lineName = args['lineName'];
        if (lineId != null) {
          _fetchLineDetails(lineId!);
        } else {
          setState(() {
            _isLoading = false;
            _error = "ID de ligne manquant";
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _error = "Données de la ligne non fournies";
        });
      }
    });

    _initializeLocation();
  }

  Future<void> _fetchLineDetails(int id) async {
    final url = Uri.parse('https://tobis-backend.onrender.com/lines/$id');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lineData = data;
          polylinePoints = decodePolyline(lineData!['polyline'] ?? '');
          stops = List<Map<String, dynamic>>.from(lineData!['stops'] ?? []);

          if (lineData!['color'] != null) {
            lineColor = _hexToColor(lineData!['color']);
          }
          _isLoading = false;
        });
      } else {
        throw Exception('Impossible de charger les détails de la ligne. Status code: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = "Erreur: ${e.toString()}";
      });
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _fabAnimationController.dispose();
    super.dispose();
  }

  Future<void> _initializeLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    if (permission == LocationPermission.deniedForever) return;

    setState(() => _isLocationEnabled = true);
    _fabAnimationController.forward();
    _startLocationTracking();
  }

  void _startLocationTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) {
      if (mounted) {
        setState(() => currentLocation = LatLng(position.latitude, position.longitude));
        if (_isFollowingLocation) {
          _mapController.move(currentLocation!, _mapController.camera.zoom);
        }
      }
    });
  }

  List<Marker> _buildStopMarkers() {
    if (stops.isEmpty) return [];
    return stops.asMap().entries.map((entry) {
      int i = entry.key;
      Map<String, dynamic> stop = entry.value;
      final lat = (stop['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (stop['longitude'] as num?)?.toDouble() ?? 0.0;

      if (lat == 0.0 && lng == 0.0) return null;

      final isFirst = i == 0;
      final isLast = i == stops.length - 1;

      return Marker(
        point: LatLng(lat, lng),
        width: isFirst || isLast ? 40 : 24,
        height: isFirst || isLast ? 40 : 24,
        child: Container(
            decoration: BoxDecoration(
              color: isFirst || isLast ? lineColor : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: lineColor, width: 2),
            ),
            child: isFirst
                ? const Icon(Icons.directions_bus, color: Colors.white, size: 20)
                : isLast
                    ? const Icon(Icons.flag, color: Colors.white, size: 20)
                    : null),
      );
    }).where((m) => m != null).toList().cast<Marker>();
  }

  void _centerOnMyLocation() {
    if (currentLocation != null) {
      _mapController.move(currentLocation!, 16.0);
      setState(() => _isFollowingLocation = true);
    }
  }

  void _centerOnRoute() {
    if (polylinePoints.isNotEmpty) {
      final bounds = _calculateBounds(polylinePoints);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)));
    }
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) return LatLngBounds(LatLng(0, 0), LatLng(0, 0));
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLng = points.first.longitude, maxLng = points.first.longitude;
    for (final point in points) {
      minLat = min(minLat, point.latitude);
      maxLat = max(maxLat, point.latitude);
      minLng = min(minLng, point.longitude);
      maxLng = max(maxLng, point.longitude);
    }
    return LatLngBounds(LatLng(minLat, minLng), LatLng(maxLat, maxLng));
  }

  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(backgroundColor: lineColor, title: Text("Ligne ${lineName ?? '...'}")),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: Colors.red, title: const Text("Erreur")),
        body: Center(child: Text(_error!, style: const TextStyle(color: Colors.red))),
      );
    }

    final routeName = lineData!['route_name'] ?? lineName ?? 'Inconnue';
    final isDotted = lineData!['type'] == 'intermittente';
    final start = stops.isNotEmpty ? stops.first['name'] ?? '...' : '...';
    final end = stops.isNotEmpty ? stops.last['name'] ?? '...' : '...';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("Ligne $routeName"),
        backgroundColor: lineColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(
                height: 280,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: polylinePoints.isNotEmpty ? polylinePoints.first : const LatLng(34.02, -6.83),
                    initialZoom: 13, maxZoom: 18, minZoom: 10,
                    onPositionChanged: (position, hasGesture) {
                      if (hasGesture && _isFollowingLocation) {
                        setState(() => _isFollowingLocation = false);
                      }
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
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
                    MarkerLayer(markers: _buildStopMarkers()),
                    if (currentLocation != null)
                      MarkerLayer(
                        markers: [Marker(point: currentLocation!, child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 32))],
                      ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                color: lineColor,
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$start → $end", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.white70, size: 16),
                        const SizedBox(width: 4),
                        Text("${stops.length} arrêts", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: stops.length,
                  itemBuilder: (context, index) {
                    final stop = stops[index];
                    final name = stop['name'] ?? 'Inconnu';
                    final isFirst = index == 0;
                    final isLast = index == stops.length - 1;

                    return ListTile(
                      leading: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isFirst ? Icons.trip_origin : Icons.circle, color: lineColor, size: isFirst ? 24 : 12),
                          if (!isLast) Expanded(child: Container(width: 2, color: lineColor)),
                        ],
                      ),
                      title: Text(name, style: TextStyle(fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(isFirst ? "Point de départ" : isLast ? "Terminus" : ''),
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isLocationEnabled)
            Positioned(
              bottom: 16, right: 16,
              child: ScaleTransition(
                scale: _fabAnimation,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FloatingActionButton(
                      heroTag: 'centerRoute',
                      onPressed: _centerOnRoute,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.timeline, color: lineColor),
                    ),
                    const SizedBox(height: 12),
                    FloatingActionButton(
                      heroTag: 'myLocation',
                      onPressed: _centerOnMyLocation,
                      backgroundColor: _isFollowingLocation ? Colors.blue : Colors.white,
                      child: Icon(Icons.my_location, color: _isFollowingLocation ? Colors.white : Colors.blue),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
