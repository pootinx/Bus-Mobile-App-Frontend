
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'search.dart';

class Stop {
  final int id;
  final String name;
  final double lat;
  final double lon;

  Stop({required this.id, required this.name, required this.lat, required this.lon});

  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'],
      name: json['name'] ?? 'Unnamed Stop',
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
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
  Future<List<Stop>>? _stopsFuture;

  @override
  void initState() {
    super.initState();
    _stopsFuture = _fetchStopsForLine(widget.route.lineId);
  }

  Future<List<Stop>> _fetchStopsForLine(int lineId) async {
    final url = 'https://tobis-backend.onrender.com/station/stops?line_id=$lineId';
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((stopJson) => Stop.fromJson(stopJson)).toList();
      } else {
        throw Exception('Failed to load stops: HTTP ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching stops: $e');
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
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
      body: FutureBuilder<List<Stop>>(
        future: _stopsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Failed to load route details:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No stops found for this line.'));
          }
          
          final allStops = snapshot.data!;
          
          return RouteDetailsView(
            key: ValueKey(widget.route.lineId), 
            route: widget.route, 
            stops: allStops,
            color: routeColor,
          );
        },
      ),
    );
  }
}

class RouteDetailsView extends StatefulWidget {
  final TobisRoute route;
  final List<Stop> stops;
  final Color color;

  const RouteDetailsView({Key? key, required this.route, required this.stops, required this.color}) : super(key: key);

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
    _setupMapData();
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
    if (widget.route.polyline != null && widget.route.polyline!.isNotEmpty) {
        final polylineCoordinates = _decodePolyline(widget.route.polyline!);
        if (polylineCoordinates.isNotEmpty) {
            _polylines.add(Polyline(
                polylineId: const PolylineId('route_line'),
                points: polylineCoordinates,
                color: widget.color,
                width: 5,
            ));
            _initialCameraPosition = _calculateCenter(polylineCoordinates);
        }
    }

    for (int i = 0; i < widget.stops.length; i++) {
      final stop = widget.stops[i];
      _markers.add(Marker(
        markerId: MarkerId(stop.id.toString()),
        position: LatLng(stop.lat, stop.lon),
        infoWindow: InfoWindow(title: stop.name),
        icon: (i == 0)
            ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen)
            : (i == widget.stops.length - 1)
              ? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)
              : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    if (_initialCameraPosition == null && _markers.isNotEmpty) {
        _initialCameraPosition = _calculateCenter(_markers.map((m) => m.position).toList());
    } else if (_initialCameraPosition == null) {
        _initialCameraPosition = const LatLng(33.57, -7.59);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) => _zoomToFitRoute());
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _zoomToFitRoute();
  }

  void _zoomToFitRoute() {
    if (_mapController == null) return;
    final points = _polylines.isNotEmpty ? _polylines.first.points : _markers.map((m) => m.position).toList();
    if (points.length > 1) {
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(_getBounds(points), 60.0));
    }
  }
  
  LatLng _calculateCenter(List<LatLng> points) {
      if(points.isEmpty) return const LatLng(33.57, -7.59);
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
    final stops = widget.stops;

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(target: _initialCameraPosition!, zoom: 12),
                  polylines: _polylines,
                  markers: _markers,
                  mapToolbarEnabled: false,
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          color: widget.color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                (stops.isNotEmpty)
                    ? '${stops.first.name} → ${stops.last.name}'
                    : 'No stops found',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text('${stops.length} stops', style: const TextStyle(color: Colors.white, fontSize: 15)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: stops.length,
            itemBuilder: (context, index) {
              final stop = stops[index];
              return ListTile(
                leading: _buildStopIndicator(index, stops.length, widget.color),
                title: Text(stop.name),
                subtitle: Text('Stop ${index + 1}', style: TextStyle(color: Colors.grey.shade600)),
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
