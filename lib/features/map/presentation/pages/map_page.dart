import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import 'package:bus_app/shared/models/directions_response.dart' as dr;
import 'package:bus_app/shared/models/firestore_route_result.dart';
import 'package:bus_app/core/utils/permission_handler.dart';

class RouteMapScreenV1 extends StatefulWidget {
  final FirestoreRouteResult route;

  const RouteMapScreenV1({super.key, required this.route});

  @override
  State<RouteMapScreenV1> createState() => _RouteMapScreenV1State();
}

class _RouteMapScreenV1State extends State<RouteMapScreenV1> {
  late GoogleMapController mapController;
  final Set<Polyline> _polylines = {};
  final Set<Marker> _markers = {};
  LatLng? userLocation;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initMap();
  }

  Future<void> _initMap() async {
    try {
      final walkRoutes = await Future.wait([
        fetchWalkingRoute(
          gmaps.LatLng(widget.route.startCoords.latitude, widget.route.startCoords.longitude),
          gmaps.LatLng(widget.route.startStopCoords.latitude, widget.route.startStopCoords.longitude),
        ),
        fetchWalkingRoute(
          gmaps.LatLng(widget.route.endStopCoords.latitude, widget.route.endStopCoords.longitude),
          gmaps.LatLng(widget.route.endCoords.latitude, widget.route.endCoords.longitude),
        ),
      ]);

      // Do not block map display on user location
      _fetchUserLocationAsync();

      setState(() {
        // Add static route markers
        _markers.addAll([
          _buildMarker(
            gmaps.LatLng(widget.route.startCoords.latitude, widget.route.startCoords.longitude),
            "Départ",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          ),
          _buildMarker(
            gmaps.LatLng(widget.route.endCoords.latitude, widget.route.endCoords.longitude),
            "Arrivée",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          ),
          _buildMarker(
            gmaps.LatLng(widget.route.startStopCoords.latitude, widget.route.startStopCoords.longitude),
            "Bus (Départ)",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
          _buildMarker(
            gmaps.LatLng(widget.route.endStopCoords.latitude, widget.route.endStopCoords.longitude),
            "Bus (Arrivée)",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          ),
        ]);

        // Add polylines
        _polylines.add(gmaps.Polyline(
          polylineId: const gmaps.PolylineId("bus_route"),
          color: Color(widget.route.colorValue),
          width: 5,
          points: widget.route.polyline
              .map((p) => gmaps.LatLng(p.latitude, p.longitude))
              .toList(),
        ));

        _polylines.add(gmaps.Polyline(
          polylineId: const gmaps.PolylineId("walk_to_start"),
          color: Colors.blue,
          width: 2,
          points: walkRoutes[0],
        ));

        _polylines.add(gmaps.Polyline(
          polylineId: const gmaps.PolylineId("walk_to_end"),
          color: Colors.blue,
          width: 2,
          points: walkRoutes[1],
        ));

        _isLoading = false;
      });
    } catch (e) {
      print("❌ Error initializing map: $e");
      setState(() => _isLoading = false);
    }
  }

  void _fetchUserLocationAsync() async {
    try {
      final granted = await PermissionHandler.handleLocationPermission(context);
      if (!granted) return;

      if (await Geolocator.isLocationServiceEnabled()) {
        final pos = await Geolocator.getCurrentPosition();
        final userPos = LatLng(pos.latitude, pos.longitude);

        setState(() {
          userLocation = userPos;
          _markers.add(_buildMarker(
            userPos,
            "Moi",
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          ));
        });
      }
    } catch (e) {
      print("⚠️ Could not get user location: $e");
    }
  }

  Marker _buildMarker(LatLng position, String label, BitmapDescriptor icon) {
    return Marker(
      markerId: MarkerId(label),
      position: position,
      icon: icon,
      infoWindow: InfoWindow(title: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Carte ${widget.route.lineName}")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: gmaps.LatLng(
                widget.route.startCoords.latitude,
                widget.route.startCoords.longitude,
              ),
              zoom: 13,
            ),
            polylines: _polylines,
            markers: _markers,
            onMapCreated: (controller) => mapController = controller,
            myLocationEnabled: userLocation != null,
            myLocationButtonEnabled: true,
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Future<List<LatLng>> fetchWalkingRoute(LatLng start, LatLng end) async {
    final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception("Missing GOOGLE_MAPS_API_KEY in .env");
    }

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/directions/json'
      '?origin=${start.latitude},${start.longitude}'
      '&destination=${end.latitude},${end.longitude}'
      '&mode=walking'
      '&key=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final directions = dr.DirectionsResponse.fromJson(json.decode(response.body));

      if (directions.status != 'OK' || directions.routes.isEmpty) {
        throw Exception('Google Directions API error: ${directions.status}');
      }

      final encodedPolyline = directions.routes.first.overviewPolyline.points;
      final decodedPoints = PolylinePoints.decodePolyline(encodedPolyline);

      return decodedPoints.map((p) => LatLng(p.latitude, p.longitude)).toList();
    } else {
      throw Exception('Failed to fetch walking route: ${response.body}');
    }
  }
}