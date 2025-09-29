
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'search.dart';

// Custom decode function provided by the user.
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
    _setupMap();
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }

  void _setupMap() {
    if (widget.route.stops.isEmpty) {
        setState(() {
            _initialCameraPosition = const LatLng(35.57, -5.35); // Default to Tetouan
        });
        return;
    }

    List<LatLng> polylineCoordinates = [];

    if (widget.route.polyline != null && widget.route.polyline!.isNotEmpty) {
      polylineCoordinates = _decodePolyline(widget.route.polyline!); // Use the custom decoder
    }

    if (polylineCoordinates.isEmpty) {
        polylineCoordinates = widget.route.stops.where((s) => s.lat != 0.0 && s.lon != 0.0).map((s) => LatLng(s.lat, s.lon)).toList();
    }
    
    if (polylineCoordinates.isEmpty) {
        setState(() {
            _initialCameraPosition = const LatLng(35.57, -5.35);
        });
        return;
    }

    _initialCameraPosition = _calculateCenter(polylineCoordinates);

    final startStop = widget.route.stops.first;
    final endStop = widget.route.stops.last;

    _markers.add(Marker(
      markerId: const MarkerId('start_stop'),
      position: LatLng(startStop.lat, startStop.lon),
      infoWindow: InfoWindow(title: startStop.name, snippet: 'Point de départ'),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
    ));
    _markers.add(Marker(
      markerId: const MarkerId('end_stop'),
      position: LatLng(endStop.lat, endStop.lon),
      infoWindow: InfoWindow(title: endStop.name, snippet: "Point d'arrivée"),
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
    ));

    _polylines.add(Polyline(
      polylineId: const PolylineId('route_line'),
      points: polylineCoordinates,
      color: _hexToColor(widget.route.color ?? '#FFA500'),
      width: 5,
    ));

    setState(() {});
  }
  
  LatLng _calculateCenter(List<LatLng> points) {
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
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _mapController != null && _polylines.isNotEmpty && _polylines.first.points.isNotEmpty) {
        LatLngBounds bounds = _getBounds(_polylines.first.points);
        _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 60.0));
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
                ? const Center(child: Text('Loading map...'))
                : GoogleMap(
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(target: _initialCameraPosition!, zoom: 12),
                    polylines: _polylines,
                    markers: _markers,
                    mapToolbarEnabled: false,
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
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
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: widget.route.stops.length,
              itemBuilder: (context, index) {
                final stop = widget.route.stops[index];
                return ListTile(
                  leading: _buildStopIndicator(index, widget.route.stops.length, routeColor),
                  title: Text(stop.name),
                  subtitle: Text(index == 0 ? 'Point de départ' : stop.time, style: TextStyle(color: Colors.grey.shade600)),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStopIndicator(int index, int stopCount, Color color) {
    return SizedBox(
      width: 40,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (index > 0)
            Expanded(
              child: Container(
                width: 2,
                color: color.withOpacity(0.3),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 2),
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: index == 0
                ? Icon(Icons.play_arrow_rounded, color: color, size: 14)
                : index == stopCount - 1 
                  ? Icon(Icons.location_on, color: color, size: 14)
                  : CircleAvatar(radius: 4, backgroundColor: color.withOpacity(0.5)),
          ),
          if (index < stopCount - 1)
            Expanded(
              child: Container(
                width: 2,
                color: color.withOpacity(0.3),
              ),
            ),
        ],
      ),
    );
  }
}
