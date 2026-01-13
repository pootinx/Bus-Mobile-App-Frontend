
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';

class RouteDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> routeData;

  const RouteDetailsScreen({Key? key, required this.routeData}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const routeName = 'Route Details';

    return Scaffold(
      appBar: AppBar(
        title: const Text(routeName),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
      ),
      body: RouteDetailsView(
        routeData: routeData,
      ),
    );
  }
}

class RouteDetailsView extends StatefulWidget {
  final Map<String, dynamic> routeData;

  const RouteDetailsView({Key? key, required this.routeData}) : super(key: key);

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

  Color _getColorForLine(String lineName) {
    final hash = lineName.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromRGBO(r, g, b, 1);
  }

  void _setupMapData() async {
    final leg = widget.routeData['legs'][0];
    final steps = leg['steps'] as List;
    
    List<LatLng> allPoints = [];
    int polylineIdCounter = 0;

    for (final step in steps) {
      final polylinePoints = _decodePolyline(step['polyline']['points']);
      allPoints.addAll(polylinePoints);

      final polylineId = 'polyline_${polylineIdCounter++}';

      if (step['travel_mode'] == 'TRANSIT') {
        final transitDetails = step['transit_details'];
        final line = transitDetails['line'];
        final lineName = line['short_name'] ?? line['name'] ?? 'Bus';
        final lineColor = _getColorForLine(lineName);
        
        _polylines.add(Polyline(
          polylineId: PolylineId(polylineId),
          points: polylinePoints,
          color: lineColor,
          width: 6,
        ));

        final departureStop = transitDetails['departure_stop'];
        final arrivalStop = transitDetails['arrival_stop'];
        final stopIcon = await _createDotMarkerBitmap(lineColor);
        _addMarker(departureStop, stopIcon);
        _addMarker(arrivalStop, stopIcon);

      } else if (step['travel_mode'] == 'WALKING') {
        _polylines.add(Polyline(
          polylineId: PolylineId(polylineId),
          points: polylinePoints,
          color: Colors.blue,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ));
      }
    }

    if (allPoints.isNotEmpty) {
      _initialCameraPosition = _calculateCenter(allPoints);
    } else {
      _initialCameraPosition = const LatLng(33.57, -7.59);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _addMarker(Map<String, dynamic> stop, BitmapDescriptor icon) {
    final location = stop['location'];
    final lat = location['lat'];
    final lng = location['lng'];
    final name = stop['name'];

    _markers.add(Marker(
      markerId: MarkerId(name),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: name),
      icon: icon,
    ));
  }

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
    
    final img = await pictureRecorder.endRecording().toImage((radius * 2).toInt(), (radius * 2).toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  List<LatLng> _decodePolyline(String encoded) {
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

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (_polylines.isNotEmpty) {
      final allPoints = _polylines.expand((p) => p.points).toList();
      if (allPoints.length > 1) {
          final bounds = _getBounds(allPoints);
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
      }
    }
  }
  
  LatLngBounds _getBounds(List<LatLng> points) {
      final lats = points.map((p) => p.latitude);
      final lngs = points.map((p) => p.longitude);
      return LatLngBounds(
        southwest: LatLng(lats.reduce(min), lngs.reduce(min)),
        northeast: LatLng(lats.reduce(max), lngs.reduce(max)),
      );
  }

  LatLng _calculateCenter(List<LatLng> points) {
    if (points.isEmpty) return const LatLng(33.57, -7.59);
    final bounds = _getBounds(points);
    return LatLng(
      (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
      (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final leg = widget.routeData['legs'][0];
    final steps = leg['steps'] as List;

    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: _initialCameraPosition ?? const LatLng(33.57, -7.59),
              zoom: 12,
            ),
            polylines: _polylines,
            markers: _markers,
            mapToolbarEnabled: false,
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final instruction = step['html_instructions'].replaceAll(RegExp(r'<[^>]*>'), '');
              final duration = step['duration']['text'];
              
              IconData iconData;
              Color stepColor = Colors.grey;
              String lineName = '';

              if(step['travel_mode'] == 'WALKING'){
                iconData = Icons.directions_walk;
                stepColor = Colors.blue;
              } else if (step['travel_mode'] == 'TRANSIT') {
                iconData = Icons.directions_bus;
                final line = step['transit_details']['line'];
                lineName = line['short_name'] ?? line['name'] ?? '';
                stepColor = _getColorForLine(lineName);
              } else {
                iconData = Icons.pin_drop;
              }

              return ListTile(
                leading: Icon(iconData, color: stepColor),
                title: Text(instruction),
                subtitle: Text(duration),
                trailing: lineName.isNotEmpty 
                    ? Text(lineName, style: TextStyle(color: stepColor, fontWeight: FontWeight.bold))
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}