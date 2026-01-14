
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math';
import 'package:bus_app/core/utils/permission_handler.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/features/map/presentation/widgets/route_step_item.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

class RouteDetailsPage extends StatefulWidget {
  final Map<String, dynamic> routeData;

  const RouteDetailsPage({Key? key, required this.routeData}) : super(key: key);

  @override
  _RouteDetailsPageState createState() => _RouteDetailsPageState();
}

class _RouteDetailsPageState extends State<RouteDetailsPage> {
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  GoogleMapController? _mapController;
  LatLng? _initialCameraPosition;
  final PanelController _panelController = PanelController();

  // For User's Live Location
  StreamSubscription<Position>? _positionStreamSubscription;
  Marker? _currentUserMarker;

  @override
  void initState() {
    super.initState();
    _setupMapData();
    _subscribeToLocationUpdates();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToLocationUpdates() async {
    try {
      final granted = await PermissionHandler.handleLocationPermission(context);
      if (!granted) return;

      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {
        final userLatLng = LatLng(position.latitude, position.longitude);
        final userMarkerIcon = await _createCurrentUserMarkerBitmap();

        setState(() {
          _currentUserMarker = Marker(
            markerId: const MarkerId('currentUser'),
            position: userLatLng,
            icon: userMarkerIcon,
            anchor: const Offset(0.5, 0.5),
            zIndex: 2,
            flat: true,
          );

          _markers.removeWhere((m) => m.markerId.value == 'currentUser');
          _markers.add(_currentUserMarker!);
        });
      });

    } catch (e) {
      debugPrint("Error subscribing to location updates: $e");
    }
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
          width: 8,
        ));

        final departureStop = transitDetails['departure_stop'];
        final arrivalStop = transitDetails['arrival_stop'];
        final stopIcon = await _createDotMarkerBitmap(lineColor);
        _addMarker(departureStop, stopIcon, 'departure_$polylineId');
        _addMarker(arrivalStop, stopIcon, 'arrival_$polylineId');

      } else if (step['travel_mode'] == 'WALKING') {
        _polylines.add(Polyline(
          polylineId: PolylineId(polylineId),
          points: polylinePoints,
          color: AppTheme.accentBlue,
          width: 5,
          patterns: [PatternItem.dot, PatternItem.gap(10)],
        ));
      }
    }

    if (allPoints.isNotEmpty) {
      _initialCameraPosition = _calculateCenter(allPoints);
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _addMarker(Map<String, dynamic> stop, BitmapDescriptor icon, String id) {
    final location = stop['location'];
    final lat = location['lat'];
    final lng = location['lng'];
    final name = stop['name'];

    _markers.add(Marker(
      markerId: MarkerId(id),
      position: LatLng(lat, lng),
      infoWindow: InfoWindow(title: name),
      icon: icon,
    ));
  }

  Future<BitmapDescriptor> _createCurrentUserMarkerBitmap() async {
      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final Paint paint = Paint();
      const double radius = 25.0;

      canvas.drawCircle(const Offset(radius, radius), radius, paint..color = Colors.blue.withOpacity(0.2));
      canvas.drawCircle(const Offset(radius, radius), radius * 0.7, paint..color = Colors.white);
      canvas.drawCircle(const Offset(radius, radius), radius * 0.4, paint..color = AppTheme.primaryBlue);

      final img = await pictureRecorder.endRecording().toImage((radius * 2).toInt(), (radius * 2).toInt());
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }

  Future<BitmapDescriptor> _createDotMarkerBitmap(Color color) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = color;
    const double radius = 18.0;

    canvas.drawCircle(const Offset(radius, radius), radius, paint);
    paint.color = Colors.white;
    canvas.drawCircle(const Offset(radius, radius), radius * 0.6, paint);
    
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
          _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
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
    final totalDuration = leg['duration']['text'];
    final arrivalTime = leg['arrival_time']?['text'] ?? '';

    return Scaffold(
      body: Stack(
        children: [
          // 1. Full Screen Map
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _initialCameraPosition ?? const LatLng(33.57, -7.59),
                zoom: 12,
              ),
              polylines: _polylines,
              markers: _markers,
              mapToolbarEnabled: false,
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
            ),
          ),

          // 2. Floating App Bar (Back Button)
          Positioned(
            top: 50,
            left: 20,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: AppTheme.primaryBlue),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // 3. Sliding Up Panel
          SlidingUpPanel(
            controller: _panelController,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            minHeight: 180,
            parallaxEnabled: true,
            parallaxOffset: 0.5,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
            panel: _buildPanel(steps, totalDuration, arrivalTime),
            collapsed: _buildCollapsedPanel(totalDuration, arrivalTime, steps),
          ),
        ],
      ),
    );
  }

  Widget _buildCollapsedPanel(String duration, String arrival, List steps) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Arrivée estimée",
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  Text(
                    arrival.isNotEmpty ? arrival : "Directement",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 6),
                    Text(
                      duration,
                      style: const TextStyle(
                        color: AppTheme.primaryBlue,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Simple mode summary icons
          _buildModeSummary(steps),
        ],
      ),
    );
  }

  Widget _buildModeSummary(List steps) {
    List<Widget> modeWidgets = [];
    for (var i = 0; i < steps.length; i++) {
      final step = steps[i];
      final mode = step['travel_mode'];
      
      IconData icon;
      Color color;
      
      if (mode == 'WALKING') {
        icon = Icons.directions_walk;
        color = Colors.grey;
      } else {
        icon = Icons.directions_bus;
        final line = step['transit_details']?['line'];
        final lineName = line?['short_name'] ?? '';
        color = lineName.isNotEmpty ? _getColorForLine(lineName) : Colors.blue;
      }

      modeWidgets.add(Icon(icon, size: 18, color: color));
      if (i < steps.length - 1) {
        modeWidgets.add(const Icon(Icons.chevron_right, size: 14, color: Colors.grey));
      }
    }

    return Row(children: modeWidgets);
  }

  Widget _buildPanel(List steps, String duration, String arrival) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              const Text(
                "Détails de l'itinéraire",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const Spacer(),
              _buildLiveBadge(),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final mode = step['travel_mode'];
              final lineName = step['transit_details']?['line']?['short_name'] ?? '';
              final color = mode == 'WALKING' ? AppTheme.accentBlue : _getColorForLine(lineName);

              return RouteStepItem(
                step: step,
                isFirst: index == 0,
                isLast: index == steps.length - 1,
                color: color,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLiveBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.5)),
      ),
      child: const Row(
        children: [
          Icon(Icons.sensors, size: 14, color: Colors.green),
          SizedBox(width: 4),
          Text(
            "LIVE",
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
