
import 'dart:async';
import 'dart:math' as math;
import 'package:bus_app/screens/bus_line_details_screen.dart';
import 'package:bus_app/services/location_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  LatLng? userLocation;

  final LocationService _locationService = LocationService();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};

  Map<String, Map<String, dynamic>> stopsMap = {};
  Map<String, dynamic>? selectedStop;
  final Map<String, List<LatLng>> _lineTrajectories = {};
  final Set<String> _displayedLines = {};
  late List<String> moroccoCities = [];

  bool locationPermissionDenied = false;
  bool loadingStops = false;

  @override
  void initState() {
    super.initState();
    fetchAndPrintCities();
    _initializeScreen();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  void _initializeScreen() async {
    try {
      final latLng = await _locationService.getCurrentLocation();
      if (!mounted) return;

      setState(() {
        userLocation = latLng;
        locationPermissionDenied = false;
        _updateMarkers();
      });

      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 14));

      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);
      if (placemarks.isNotEmpty) {
        final city = placemarks.first.locality?.toLowerCase().trim();
        if (city != null && city.isNotEmpty) {
          _fetchStopsFromLines(city);
        }
      }
    } catch (e) {
      if (!mounted) return;
      print('❌ Location permission denied or error in StationsScreen: $e');
      setState(() => locationPermissionDenied = true);
    }
  }

  Future<void> _fetchStopsFromLines(String query) async {
    if (userLocation == null) return;
    setState(() => loadingStops = true);

    try {
      final bestCity = await _findClosestValidCityCollection(query);
      if (bestCity == null) {
        setState(() => loadingStops = false);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Aucune ville correspondante trouvée.')),
          );
        }
        return;
      }

      final linesSnapshot = await FirebaseFirestore.instance.collection(bestCity).get();
      final Map<String, Map<String, dynamic>> tempStops = {};

      for (final lineDoc in linesSnapshot.docs) {
        final lineId = lineDoc.id;
        final lineData = lineDoc.data();
        final encodedPolyline = lineData['polyline'];
        if (encodedPolyline == null) continue;

        _lineTrajectories.putIfAbsent(
          lineId,
          () => _smoothTrajectory(_decodePolyline(encodedPolyline)),
        );

        final stops = lineData['stops'] ?? [];
        for (final stop in stops) {
          final name = stop['name'];
          final lat = stop['lat']?.toDouble();
          final lon = stop['lon']?.toDouble();
          if (name == null || lat == null || lon == null) continue;

          final key = '$name-$lat-$lon';
          final lineDetails = {
            'line_id': lineDoc.id,
            'route_name': lineData['route_name'] ?? 'Ligne Inconnue',
            'color': lineData['color'] ?? '#0000FF',
            'polyline': encodedPolyline,
            'stops': lineData['stops'],
          };

          if (tempStops.containsKey(key)) {
            tempStops[key]!['lines'].add(lineDetails);
          } else {
            tempStops[key] = {
              'name': name,
              'lat': lat,
              'lon': lon,
              'lines': [lineDetails],
            };
          }
        }
      }

      final userPos = userLocation!;
      final sortedStops = tempStops.values.toList()
        ..sort((a, b) {
          final d1 = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, a['lat'], a['lon']);
          final d2 = Geolocator.distanceBetween(userPos.latitude, userPos.longitude, b['lat'], b['lon']);
          return d1.compareTo(d2);
        });

      final closestThree = sortedStops.take(3);
      final filteredStops = <String, Map<String, dynamic>>{};
      for (var stop in closestThree) {
        final key = '${stop['name']}-${stop['lat']}-${stop['lon']}';
        filteredStops[key] = stop;
      }

      setState(() {
        stopsMap = filteredStops;
        loadingStops = false;
        _updateMarkers();
        _updatePolylines();
      });

    } catch (e) {
      setState(() => loadingStops = false);
      debugPrint('Firestore error: $e');
    }
  }

  void _updateMarkers() {
    _markers.clear();

    if (userLocation != null) {
      _markers.add(Marker(
        markerId: const MarkerId('user_location'),
        position: userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Ma Position'),
      ));
    }

    for (final stop in stopsMap.values) {
       final lat = stop['lat'];
       final lon = stop['lon'];
       final name = stop['name'];
       final markerId = MarkerId('stop_$name-$lat-$lon');

       final bool isSelected = selectedStop != null && selectedStop!['name'] == name && selectedStop!['lat'] == lat;

       _markers.add(Marker(
         markerId: markerId,
         position: LatLng(lat, lon),
         infoWindow: InfoWindow(title: name),
         icon: BitmapDescriptor.defaultMarkerWithHue( isSelected ? BitmapDescriptor.hueViolet : BitmapDescriptor.hueOrange),
         onTap: () => _selectStop(stop),
         zIndex: isSelected ? 2 : 1,
       ));
    }
    
     for (final id in _displayedLines) {
      final traj = _lineTrajectories[id] ?? [];
      if (traj.isEmpty) continue;
      _markers.add(Marker(markerId: MarkerId('start_$id'), position: traj.first, icon: _createEndpointIcon(_getLineColor(id), Icons.play_arrow)));
      _markers.add(Marker(markerId: MarkerId('end_$id'), position: traj.last, icon: _createEndpointIcon(_getLineColor(id), Icons.stop)));
    }
  }

  void _updatePolylines() {
    _polylines.clear();
    for (final lineId in _displayedLines) {
      if (_lineTrajectories.containsKey(lineId)) {
        _polylines.add(Polyline(
          polylineId: PolylineId(lineId),
          points: _lineTrajectories[lineId]!,
          color: _getLineColor(lineId),
          width: 5,
        ));
      }
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
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

  List<LatLng> _smoothTrajectory(List<LatLng> trajectory) {
     if (trajectory.length < 3) return trajectory;
    final smoothed = <LatLng>[trajectory.first];
    for (var i = 1; i < trajectory.length - 1; i++) {
      final prev = trajectory[i - 1];
      final curr = trajectory[i];
      final next = trajectory[i + 1];
      smoothed.add(LatLng(
        (prev.latitude + curr.latitude + next.latitude) / 3,
        (prev.longitude + curr.longitude + next.longitude) / 3,
      ));
    }
    smoothed.add(trajectory.last);
    return smoothed;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  Color _getLineColor(String lineId) {
    for (final stop in stopsMap.values) {
      for (final l in stop['lines']) {
        if (l['line_id'] == lineId) return _hexToColor(l['color']);
      }
    }
    final rand = math.Random(lineId.hashCode);
    return Color.fromARGB(255, 100 + rand.nextInt(155), 100 + rand.nextInt(155), 100 + rand.nextInt(155));
  }

  void _toggleLineTrajectory(String lineId) {
    setState(() {
      if (_displayedLines.contains(lineId)) {
        _displayedLines.remove(lineId);
      } else {
        _displayedLines.add(lineId);
      }
      _updateMarkers();
      _updatePolylines();
    });
  }

  void _selectStop(Map<String, dynamic> stop) {
    setState(() {
      selectedStop = stop;
      _updateMarkers();
    });

    _mapController?.animateCamera(
      CameraUpdate.newLatLng(LatLng(stop['lat'], stop['lon'])),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final lines = stop['lines'] as List<dynamic>;
        final ids = <String>{};
        final uniqueLines = lines.where((l) => ids.add(l['line_id'].toString())).toList();

        return DraggableScrollableSheet(
          initialChildSize: 0.4,
          minChildSize: 0.2,
          maxChildSize: 0.6,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(stop['name'], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: uniqueLines.length,
                    itemBuilder: (context, index) {
                      final line = uniqueLines[index];
                      final lineId = line['line_id'];
                      return ListTile(
                        leading: Icon(Icons.directions_bus, color: _hexToColor(line['color'])),
                        title: Text(line['route_name'] ?? 'Ligne $lineId'),
                        trailing: IconButton(
                          icon: Icon(_displayedLines.contains(lineId) ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            _toggleLineTrajectory(lineId);
                            Navigator.pop(ctx); 
                          },
                        ),
                        onTap: () {
                           Navigator.pop(ctx);
                           Navigator.push(
                             context,
                             MaterialPageRoute(builder: (_) => BusLineDetailsScreen(lineData: Map<String, dynamic>.from(line),),)
                           );
                        },
                      );
                    },
                  ),
                )
              ],
            );
          },
        );
      },
    ).whenComplete(() {
      setState(() {
        selectedStop = null;
        _updateMarkers();
      });
    });
  }
  
  Future<void> fetchAndPrintCities() async { 
     moroccoCities = await getFirestoreCities();
  }
  
  Future<List<String>> getFirestoreCities() async {
     try {
      final snapshot = await FirebaseFirestore.instance.collection('cities').get();
      return snapshot.docs
          .map((doc) => doc.data()['name']?.toString().toLowerCase().trim())
          .where((name) => name != null && name.isNotEmpty)
          .cast<String>()
          .toList();
    } catch (e) {
      debugPrint('Error fetching cities: $e');
      return [];
    }
  }

  Future<String?> _findClosestValidCityCollection(String query) async {
    final input = query.toLowerCase().trim();
    moroccoCities.sort((a, b) =>
        _levenshteinDistance(input, a).compareTo(_levenshteinDistance(input, b)));

    for (final city in moroccoCities) {
      try {
        final snapshot = await FirebaseFirestore.instance.collection(city).limit(1).get();
        if (snapshot.docs.isNotEmpty) return city;
      } catch (e) {
        // collection might not exist, continue
      }
    }
    return null;
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<int> v0 = List<int>.filled(t.length + 1, 0);
    List<int> v1 = List<int>.filled(t.length + 1, 0);

    for (int i = 0; i < t.length + 1; i++) v0[i] = i;

    for (int i = 0; i < s.length; i++) {
        v1[0] = i + 1;
        for (int j = 0; j < t.length; j++) {
            int cost = (s[i] == t[j]) ? 0 : 1;
            v1[j + 1] = math.min(v1[j] + 1, math.min(v0[j + 1] + 1, v0[j] + cost));
        }
        for (int j = 0; j < t.length + 1; j++) {
            v0[j] = v1[j];
        }
    }
    return v1[t.length];
  }
  
  BitmapDescriptor _createEndpointIcon(Color c, IconData ic) {
      if (ic == Icons.play_arrow) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
      if (ic == Icons.stop) return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      return BitmapDescriptor.defaultMarker;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Arrêts à proximité', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(
              target: userLocation ?? const LatLng(34.020882, -6.84165), // Default to Rabat
              zoom: 13,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationButtonEnabled: true,
            myLocationEnabled: false, // Using custom marker
            zoomControlsEnabled: true,
          ),
          if (loadingStops)
            const Positioned(
              top: 10,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('Chargement des arrêts…'),
                  ),
                ),
              ),
            ),
          if (locationPermissionDenied)
             Positioned(
              top: 10,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(10)),
                child: const Text('Géolocalisation refusée. La position par défaut est affichée.', style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}
