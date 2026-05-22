import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:bus_app/core/services/google_directions_service.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

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
  
  // Custom UI state
  int? _expandedIndex;
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();
  final Map<int, List<DateTime>> _stopArrivals = {};
  final Map<int, bool> _isLoadingArrivals = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final data = widget.lineData;
    final List<LatLng> polylinePoints = _decodePolyline(data['polyline'] ?? '');
    stops = List<Map<String, dynamic>>.from(data['stops'] ?? []);

    // Determine line color
    if (data['color_final'] != null && data['color_final'] is Color) {
      lineColor = data['color_final'];
    } else if (data['color'] != null && data['color'] is String) {
      lineColor = _hexToColor(data['color']);
    } else {
      lineColor = AppTheme.primaryBlue;
    }

    await _setupGoogleMapData(polylinePoints, stops);
    _initializeLocation();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // --- Location and Map Methods ---

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

  Future<void> _setupGoogleMapData(List<LatLng> polylinePoints, List<Map<String, dynamic>> stops) async {
    final polyId = widget.lineData['route_name']?.toString() ?? 'line';
    final Set<Polyline> newPolylines = {
      Polyline(
        polylineId: PolylineId(polyId),
        points: polylinePoints,
        color: lineColor,
        width: 6,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      )
    };

    final Set<Marker> newMarkers = {};
    
    // Generate custom premium markers
    final startMarkerIcon = await _getDotMarker(Colors.green);
    final endMarkerIcon = await _getDotMarker(Colors.red);
    final intermediateMarkerIcon = await _getDotMarker(lineColor, size: 40.0, radius: 10.0, strokeWidth: 3.0);

    for (int i = 0; i < stops.length; i++) {
        final stop = stops[i];
        final double lat = _parseCoordinate(stop['latitude'] ?? stop['lat']);
        final double lng = _parseCoordinate(stop['longitude'] ?? stop['lon'] ?? stop['lng']);
        
        if (lat != 0.0 || lng != 0.0) {
            BitmapDescriptor icon = intermediateMarkerIcon;
            if (i == 0) {
                icon = startMarkerIcon;
            } else if (i == stops.length - 1) {
                icon = endMarkerIcon;
            }
            
            newMarkers.add(Marker(
                markerId: MarkerId("${stop['name']}_$i"),
                position: LatLng(lat, lng),
                icon: icon,
                anchor: const Offset(0.5, 0.5),
                infoWindow: InfoWindow(title: stop['name']),
            ));
        }
    }

    if (polylinePoints.isNotEmpty) {
      _initialCameraPosition = _calculateCenter(polylinePoints);
    }

    if (mounted) {
      setState(() {
        _polylines.clear();
        _polylines.addAll(newPolylines);
        _markers.clear();
        _markers.addAll(newMarkers);
      });
      // Center the map now that polylines are populated
      if (_mapController != null) {
        _centerOnRoute();
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _centerOnRoute();
  }

  void _centerOnRoute() {
    if (_mapController == null || _polylines.isEmpty) return;
    final bounds = _calculateBounds(_polylines.first.points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.0));
  }

  // --- Build Methods ---

  @override
  Widget build(BuildContext context) {
    final routeName = widget.lineData['route_name'] ?? 'Inconnue';
    final start = stops.isNotEmpty ? stops.first['name'] ?? '...' : '...';
    final end = stops.isNotEmpty ? stops.last['name'] ?? '...' : '...';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: CustomScrollView(
        slivers: [
          // Premium SliverAppBar with Map
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            stretch: true,
            backgroundColor: lineColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.white24,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Get.back(),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: GoogleMap(
                mapType: MapType.normal,
                initialCameraPosition: CameraPosition(
                  target: _initialCameraPosition ?? const LatLng(34.02, -6.83),
                  zoom: 12,
                ),
                onMapCreated: _onMapCreated,
                polylines: _polylines,
                markers: _markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: IconButton(
                    icon: const Icon(Icons.center_focus_strong, color: Colors.white, size: 20),
                    onPressed: _centerOnRoute,
                  ),
                ),
              ),
            ],
          ),

          // Route Overview Panel
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(8)),
                        child: Text(routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "$start → $end",
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildInfoItem(Icons.location_on_outlined, "${stops.length} Arrêts"),
                      _buildInfoItem(Icons.timer_outlined, "Freq. 15 min"),
                      _buildInfoItem(Icons.directions_bus_outlined, "Actif"),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Timeline Stops List
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final stop = stops[index];
                  final isExpanded = _expandedIndex == index;
                  
                  return _buildTimelineStop(index, stop, isExpanded);
                },
                childCount: stops.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _centerOnRoute,
        label: const Text("Rafraîchir"),
        icon: const Icon(Icons.refresh),
        backgroundColor: lineColor,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
      ],
    );
  }

  Widget _buildTimelineStop(int index, Map<String, dynamic> stop, bool isExpanded) {
    final isFirst = index == 0;
    final isLast = index == stops.length - 1;
    final name = stop['name'] ?? 'Arrêt';

    return GestureDetector(
      onTap: () async {
        if (!isExpanded) {
          _fetchArrivalTimes(index, stop);
        }
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Timeline line and dot
              Column(
                children: [
                  Expanded(child: Container(width: 2, color: isFirst ? Colors.transparent : lineColor.withOpacity(0.3))),
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: isFirst || isLast ? lineColor : Colors.white,
                      border: Border.all(color: lineColor, width: 2),
                      shape: BoxShape.circle,
                    ),
                  ),
                  Expanded(child: Container(width: 2, color: isLast ? Colors.transparent : lineColor.withOpacity(0.3))),
                ],
              ),
              const SizedBox(width: 20),
              // Stop Content
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isExpanded ? lineColor.withOpacity(0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontWeight: isFirst || isLast ? FontWeight.bold : FontWeight.w500,
                                fontSize: 16,
                                color: isFirst || isLast ? lineColor : null,
                              ),
                            ),
                          ),
                          Icon(isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                        ],
                      ),
                      if (isExpanded) ...[
                        const SizedBox(height: 12),
                        const Text("Prochains passages :", style: TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),
                        if (_isLoadingArrivals[index] ?? false)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else if (_stopArrivals[index]?.isNotEmpty ?? false)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _stopArrivals[index]!
                                  .map((dt) => _buildRelativeTimeBadge(dt))
                                  .toList(),
                            ),
                          )
                        else if (isExpanded)
                          const Text("Aucun passage trouvé", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeBadge(String time, bool isNext) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNext ? lineColor : lineColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        time,
        style: TextStyle(
          color: isNext ? Colors.white : lineColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildRelativeTimeBadge(DateTime departureTime) {
    final now = DateTime.now();
    final difference = departureTime.difference(now);
    final minutes = difference.inMinutes;
    String label;
    bool isNext = false;

    if (minutes < 1) {
      label = "Imminent";
      isNext = true;
    } else if (minutes < 60) {
      label = "Dans $minutes min";
      if (minutes < 10) isNext = true;
    } else {
      final hours = difference.inHours;
      final remainingMinutes = minutes % 60;
      if (hours < 24) {
        label = "Dans ${hours}h ${remainingMinutes}min";
      } else {
        label = DateFormat('HH:mm').format(departureTime);
      }
    }

    return _buildTimeBadge(label, isNext);
  }

  Future<BitmapDescriptor> _getDotMarker(Color color, {double size = 60.0, double radius = 18.0, double strokeWidth = 5.0}) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);

    // Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(Offset(size / 2, size / 2 + 2), radius + 2, shadowPaint);

    // White Border
    final Paint borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius + strokeWidth / 2, borderPaint);

    // Main Dot
    final Paint dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size / 2, size / 2), radius - strokeWidth / 2, dotPaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  Future<void> _fetchArrivalTimes(int index, Map<String, dynamic> stop) async {
    if (_isLoadingArrivals[index] == true) return;

    setState(() {
      _isLoadingArrivals[index] = true;
    });

    try {
      final double lat = _parseCoordinate(stop['latitude'] ?? stop['lat']);
      final double lng = _parseCoordinate(stop['longitude'] ?? stop['lon'] ?? stop['lng']);
      
      // Use terminus as destination
      final terminus = stops.last;
      final double destLat = _parseCoordinate(terminus['latitude'] ?? terminus['lat']);
      final double destLng = _parseCoordinate(terminus['longitude'] ?? terminus['lon'] ?? terminus['lng']);

      final result = await _directionsService.getBusDirections(
        LatLng(lat, lng),
        LatLng(destLat, destLng),
      );

      final List<DateTime> arrivalTimes = [];
      if (result['routes'] != null) {
        for (var route in result['routes']) {
          for (var leg in route['legs']) {
            for (var step in leg['steps']) {
              if (step['travel_mode'] == 'TRANSIT' && step['transit_details'] != null) {
                final details = step['transit_details'];
                // Optional: Check if the line name matches
                // final lineName = details['line']?['short_name'] ?? details['line']?['name'];
                
                final departureTimeValue = details['departure_time']?['value'];
                if (departureTimeValue != null) {
                  arrivalTimes.add(DateTime.fromMillisecondsSinceEpoch(departureTimeValue * 1000));
                }
              }
            }
          }
        }
      }

      // Sort and take next 3
      arrivalTimes.sort();
      final now = DateTime.now();
      final upcoming = arrivalTimes.where((dt) => dt.isAfter(now)).take(3).toList();

      if (mounted) {
        setState(() {
          _stopArrivals[index] = upcoming;
          _isLoadingArrivals[index] = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching arrival times: $e");
      if (mounted) {
        setState(() {
          _isLoadingArrivals[index] = false;
        });
      }
    }
  }

  // --- Helpers ---

  double _parseCoordinate(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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
}
