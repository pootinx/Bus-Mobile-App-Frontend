
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'search.dart'; 

class LineDetails {
  final String routeName;
  final String? color;
  final String? polyline;
  final List<LineStop> stops;

  LineDetails({
    required this.routeName,
    this.color,
    this.polyline,
    required this.stops,
  });

  factory LineDetails.fromJson(Map<String, dynamic> json) {
    var stopsList = json['stops'] as List<dynamic>? ?? [];
    List<LineStop> stops = stopsList.map((i) => LineStop.fromJson(i)).toList();
    
    return LineDetails(
      routeName: json['route_name'] ?? 'Unnamed Route',
      color: json['color'],
      polyline: json['polyline'],
      stops: stops,
    );
  }
}

class LineStop {
  final int id;
  final String name;
  final double lat;
  final double lon;
  final String time;

  LineStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.time,
  });

  factory LineStop.fromJson(Map<String, dynamic> json) {
    double parseCoordinate(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return LineStop(
      id: json['id'],
      name: json['name'],
      lat: parseCoordinate(json['lat']),
      lon: parseCoordinate(json['lon']),
      time: json['time'] ?? '--:--',
    );
  }
}

class RouteDetailsScreen extends StatefulWidget {
  final TobisRoute route;

  const RouteDetailsScreen({Key? key, required this.route}) : super(key: key);

  @override
  _RouteDetailsScreenState createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  Future<LineDetails>? _detailsFuture;

  @override
  void initState() {
    super.initState();
    _detailsFuture = _fetchLineDetails();
  }

  Future<LineDetails> _fetchLineDetails() async {
    final lineId = widget.route.lineId;
    final url = 'https://tobis-backend.onrender.com/itinerary/routes/$lineId';
    
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic>) {
            if (data.containsKey('line')) {
                return LineDetails.fromJson(data['line']);
            } else if (data.containsKey('route')) {
                return LineDetails.fromJson(data['route']);
            } else {
                return LineDetails.fromJson(data);
            }
        }
         throw Exception('API response format is not a valid map.');
      } else {
        throw Exception('Failed to load line details: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching line details: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeColor = _hexToColor(widget.route.color ?? '#FFA500');

    return Scaffold(
      appBar: AppBar(
        title: Text('Ligne ${widget.route.routeName}'),
        backgroundColor: routeColor,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<LineDetails>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load route map:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No route data found.'));
          }
          
          final lineDetails = snapshot.data!;
          
          return RouteDetailsView(
            key: ValueKey(lineDetails.routeName), 
            details: lineDetails,
            color: routeColor,
          );
        },
      ),
    );
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
}

class RouteDetailsView extends StatefulWidget {
  final LineDetails details;
  final Color color;

  const RouteDetailsView({Key? key, required this.details, required this.color}) : super(key: key);

  @override
  _RouteDetailsViewState createState() => _RouteDetailsViewState();
}

class _RouteDetailsViewState extends State<RouteDetailsView> {
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  LatLng? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    // --- IMPLEMENTING THE SUGGESTED QUICK FIX ---
    final validStops = widget.details.stops.where((s) => s.lat != 0.0 && s.lon != 0.0).toList();
    if (validStops.isEmpty) {
        _initialCameraPosition = const LatLng(33.57, -7.59); // Default Casablanca
    } else {
        _initialCameraPosition = _calculateCenter(validStops.map((s) => LatLng(s.lat, s.lon)).toList());
    }
    _setupMapData();

    // --- ADDING DEBUG PRINTS ---
    print('--- MAP DEBUG INFO ---');
    print('Initial camera position: $_initialCameraPosition');
    print('Polylines count: ${_polylines.length}');
    if(_polylines.isNotEmpty) print('Polyline points: ${_polylines.first.points.length}');
    print('Markers count: ${_markers.length}');
    print('----------------------');
  }
  
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length, lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      shift = 0; result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  void _setupMapData() {
    final validStops = widget.details.stops.where((s) => s.lat != 0.0 && s.lon != 0.0).toList();
    if (validStops.isEmpty) return;

    for (int i = 0; i < validStops.length; i++) {
      final stop = validStops[i];
      _markers.add(Marker(
        markerId: MarkerId('${stop.id}_$i'), // Ensure unique marker IDs
        position: LatLng(stop.lat, stop.lon),
        infoWindow: InfoWindow(title: stop.name, snippet: 'Stop ${i+1}'),
        icon: (i == 0) 
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : (i == validStops.length - 1) 
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    List<LatLng> polylineCoordinates;
    if (widget.details.polyline != null && widget.details.polyline!.isNotEmpty) {
      polylineCoordinates = _decodePolyline(widget.details.polyline!);
    } else {
      polylineCoordinates = validStops.map((s) => LatLng(s.lat, s.lon)).toList();
    }

    if (polylineCoordinates.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_line'),
        points: polylineCoordinates,
        color: widget.color,
        width: 5,
      ));
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _zoomToFitRoute();
  }

  void _zoomToFitRoute() {
    if (_mapController == null) return;
    
    final points = _polylines.isNotEmpty ? _polylines.first.points : _markers.map((m) => m.position).toList();

    if (points.length > 1) {
      final bounds = _getBounds(points);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
    } else if (points.length == 1) {
       _mapController!.animateCamera(CameraUpdate.newLatLngZoom(points.first, 15));
    }
  }
  
  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(33.57, -7.59);
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLon = points.first.longitude, maxLon = points.first.longitude;
    for (final point in points) {
        minLat = (point.latitude < minLat) ? point.latitude : minLat;
        maxLat = (point.latitude > maxLat) ? point.latitude : maxLat;
        minLon = (point.longitude < minLon) ? point.longitude : minLon;
        maxLon = (point.longitude > maxLon) ? point.longitude : maxLon;
    }
    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    return LatLngBounds(
      southwest: LatLng(points.map((p) => p.latitude).reduce((a,b) => a < b ? a : b), points.map((p) => p.longitude).reduce((a,b) => a < b ? a : b)),
      northeast: LatLng(points.map((p) => p.latitude).reduce((a,b) => a > b ? a : b), points.map((p) => p.longitude).reduce((a,b) => a > b ? a : b)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: (_initialCameraPosition == null)
              ? const Center(child: Text('Calculating route...'))
              : GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _initialCameraPosition!, zoom: 12),
                  polylines: _polylines,
                  markers: _markers,
                  mapToolbarEnabled: false,
                  onCameraIdle: () => _zoomToFitRoute(), // Recenter map when user moves it
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          color: widget.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (widget.details.stops.isNotEmpty)
                    ? '${widget.details.stops.first.name} → ${widget.details.stops.last.name}'
                    : 'No stops found',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.alt_route, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('${widget.details.stops.length} arrêts', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: widget.details.stops.length,
            itemBuilder: (context, index) {
              final stop = widget.details.stops[index];
              return ListTile(
                leading: _buildStopIndicator(index, widget.details.stops.length, widget.color),
                title: Text(stop.name),
                subtitle: Text(index == 0 ? 'Point de départ' : stop.time, style: TextStyle(color: Colors.grey.shade600)),
              );
            },
          ),
        )
      ],
    );
  }

  Widget _buildStopIndicator(int index, int stopCount, Color color) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (index > 0) Expanded(child: Container(width: 2, color: color.withOpacity(0.3))),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: (index == 0)
                ? Icon(Icons.play_arrow_rounded, color: color, size: 14)
                : (index == stopCount - 1)
                  ? Icon(Icons.location_on, color: color, size: 14)
                  : CircleAvatar(radius: 4, backgroundColor: color.withOpacity(0.5)),
          ),
          if (index < stopCount - 1) Expanded(child: Container(width: 2, color: color.withOpacity(0.3))),
        ],
      ),
    );
  }
}
