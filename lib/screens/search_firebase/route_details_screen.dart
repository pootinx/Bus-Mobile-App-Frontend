
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search.dart'; // Assuming TobisRoute is in search.dart

// Custom polyline decoding function
List<LatLng> _decodePolyline(String encoded) {
  List<LatLng> polyline = [];
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

    polyline.add(LatLng(lat / 1E5, lng / 1E5));
  }
  return polyline;
}

class RouteDetailsScreen extends StatefulWidget {
  final TobisRoute route;

  const RouteDetailsScreen({Key? key, required this.route}) : super(key: key);

  @override
  _RouteDetailsScreenState createState() => _RouteDetailsScreenState();
}

class _RouteDetailsScreenState extends State<RouteDetailsScreen> {
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  LatLng? _initialCameraPosition;

  @override
  void initState() {
    super.initState();
    _setupMapData();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex'; // Add alpha if missing
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _setupMapData() {
    // Filter out stops that don't have valid coordinates
    final validStops = widget.route.stops
        .where((s) => s.lat != 0.0 && s.lon != 0.0)
        .toList();

    if (validStops.isEmpty) {
      setState(() {
        // Default to a central location if no stops are valid
        _initialCameraPosition = const LatLng(35.57, -5.35); // Centered on Tetouan
      });
      return;
    }

    // --- 1. Create Markers for ALL valid stops ---
    for (int i = 0; i < validStops.length; i++) {
      final stop = validStops[i];
      BitmapDescriptor icon;

      if (i == 0) {
        // First stop: Green marker
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      } else if (i == validStops.length - 1) {
        // Last stop: Red marker
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      } else {
        // Intermediate stops: Orange marker
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange);
      }

      _markers.add(Marker(
        markerId: MarkerId(stop.id.toString()),
        position: LatLng(stop.lat, stop.lon),
        infoWindow: InfoWindow(title: stop.name, snippet: 'Arrêt ${i + 1}'),
        icon: icon,
        anchor: const Offset(0.5, 0.5), // Center the small icons
      ));
    }

    // --- 2. Create the Polyline for the route ---
    List<LatLng> polylineCoordinates;

    // Use the detailed polyline if available
    if (widget.route.polyline != null && widget.route.polyline!.isNotEmpty) {
      polylineCoordinates = _decodePolyline(widget.route.polyline!);
    } else {
      // Fallback: create a line by connecting the stops
      polylineCoordinates = validStops.map((s) => LatLng(s.lat, s.lon)).toList();
    }

    if (polylineCoordinates.isNotEmpty) {
      _polylines.add(Polyline(
        polylineId: const PolylineId('route_line'),
        points: polylineCoordinates,
        color: _hexToColor(widget.route.color ?? '#FFA500'), // Use line color
        width: 5,
      ));
    }

    // --- 3. Set the initial camera position ---
    // It will be quickly updated by `_onMapCreated` to fit the bounds
     _initialCameraPosition = _calculateCenter(polylineCoordinates);


    setState(() {}); // Trigger a rebuild with the new markers and polylines
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(35.57, -5.35); // Default
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLon = points.first.longitude, maxLon = points.first.longitude;

    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }
    return LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
  }
  
  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Animate camera to fit the entire route
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _mapController != null && _polylines.isNotEmpty) {
        final points = _polylines.first.points;
        if (points.isNotEmpty) {
          final bounds = _getBounds(points);
          _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0)); // 60px padding
        }
      }
    });
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double minLat = points.first.latitude, maxLat = points.first.latitude;
    double minLon = points.first.longitude, maxLon = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
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
      body: Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.4,
            child: _initialCameraPosition == null
                ? const Center(child: CircularProgressIndicator())
                : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(target: _initialCameraPosition!, zoom: 12),
                    polylines: _polylines,
                    markers: _markers,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                  ),
          ),
          // Header below map
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: routeColor,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${widget.route.stops.first.name} → ${widget.route.stops.last.name}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.alt_route, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('${widget.route.stops.length} arrêts', style: const TextStyle(color: Colors.white)),
                    const SizedBox(width: 16),
                    const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Text('${widget.route.rideEtaMin} min', style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ],
            ),
          ),
          // Scrollable list of stops
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.route.stops.length,
              itemBuilder: (context, index) {
                final stop = widget.route.stops[index];
                return ListTile(
                  leading: _buildStopIndicator(index, widget.route.stops.length, routeColor),
                  title: Text(stop.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(stop.time, style: TextStyle(color: Colors.grey.shade600)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  // Helper to build the visual indicator for the stop list
  Widget _buildStopIndicator(int index, int stopCount, Color color) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (index > 0)
            Expanded(
              child: Container(width: 2, color: color.withOpacity(0.3)),
            ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: index == 0
                ? Icon(Icons.play_arrow, color: color, size: 14)
                : index == stopCount - 1
                    ? Icon(Icons.location_on, color: color, size: 14)
                    : CircleAvatar(radius: 4, backgroundColor: color.withOpacity(0.5)),
          ),
          if (index < stopCount - 1)
            Expanded(
              child: Container(width: 2, color: color.withOpacity(0.3)),
            ),
        ],
      ),
    );
  }
}
