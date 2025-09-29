
import 'dart:async';
import 'dart:math' as math;
import 'package:bus_app/screens/bus_line_details_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class StationsScreen extends StatefulWidget {
  const StationsScreen({super.key});

  @override
  State<StationsScreen> createState() => _StationsScreenState();
}

class _StationsScreenState extends State<StationsScreen> with TickerProviderStateMixin {
  LatLng? userLocation;
  Marker? _userMarker;
  StreamSubscription<Position>? _positionStream;

  Map<String, Map<String, dynamic>> stopsMap = {};
  Map<String, dynamic>? selectedStop;
  final MapController _mapController = MapController();
  final Map<String, List<LatLng>> _lineTrajectories = {};
  final Set<String> _displayedLines = {};
  late List<String> moroccoCities = [];

  bool locationPermissionDenied = false;
  bool loadingStops = false;

  @override
  void initState() {
    super.initState();
    fetchAndPrintCities();
    _startLocationTrackingAndAutoSearch();
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    super.dispose();
  }

  void _startLocationTrackingAndAutoSearch() async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
    setState(() => locationPermissionDenied = true);
    return;
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  final latLng = LatLng(position.latitude, position.longitude);
  setState(() {
    userLocation = latLng;
    _userMarker = Marker(
      point: latLng,
      width: 40,
      height: 40,
      child: const Icon(Icons.person_pin_circle, color: Colors.blue, size: 40),
    );
  });

  try {
    final placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      final city = placemarks.first.locality?.toLowerCase().trim();
      if (city != null && city.isNotEmpty) {
        print("📍 Current city: $city");
        _mapController.move(latLng, 14);
        _fetchStopsFromLines(city);
      }
    }
  } catch (e) {
    print('❌ Reverse geocoding failed: $e');
  }
}


  void fetchAndPrintCities() async {
    moroccoCities = await getFirestoreCities();
    print('✅ Liste des villes depuis Firestore: $moroccoCities');
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

  Future<void> _fetchStopsFromLines(String query) async {
    if (userLocation == null) return;
    setState(() => loadingStops = true);

    try {
      final bestCity = await _findClosestValidCityCollection(query);

      if (bestCity == null) {
        setState(() => loadingStops = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucune ville correspondante trouvée.')),
        );
        return;
      }

      final linesSnapshot = await FirebaseFirestore.instance.collection(bestCity).get();
      final Map<String, Map<String, dynamic>> tempStops = {};

      for (final lineDoc in linesSnapshot.docs) {
        final lineId = lineDoc.id;
        final lineData = lineDoc.data();
        final encodedPolyline = lineData['polyline'];
        if (encodedPolyline == null) continue;

        final lineName = lineData['route_name'] ?? lineData['name'] ?? lineId;
        final lineColor = lineData['color'] ?? '#000000';

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
            'line_id': lineId,
            'route_name': lineName,
            'color': lineColor,
            'color_final': _hexToColor(lineColor),
            'polyline_points': _lineTrajectories[lineId],
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
      final distance = const Distance();

      final sortedStops = tempStops.values.toList()
        ..sort((a, b) {
          final d1 = distance(userPos, LatLng(a['lat'], a['lon']));
          final d2 = distance(userPos, LatLng(b['lat'], b['lon']));
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
      });


      if (tempStops.isEmpty && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Aucun arrêt trouvé pour cette ville.')),
        );
      }
    } catch (e) {
      setState(() => loadingStops = false);
      debugPrint('Firestore error: $e');
    }
  }


  Future<String?> _findClosestValidCityCollection(String query) async {
    final input = query.toLowerCase().trim();
    moroccoCities.sort((a, b) =>
        _levenshteinDistance(input, a).compareTo(_levenshteinDistance(input, b)));

    for (final city in moroccoCities) {
      final snapshot = await FirebaseFirestore.instance.collection(city).limit(1).get();
      if (snapshot.docs.isNotEmpty) return city;
    }

    return null;
  }

  int _levenshteinDistance(String s, String t) {
    if (s == t) return 0;
    if (s.isEmpty) return t.length;
    if (t.isEmpty) return s.length;

    List<List<int>> dp = List.generate(s.length + 1, (_) => List.filled(t.length + 1, 0));
    for (int i = 0; i <= s.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= t.length; j++) {
      dp[0][j] = j;
    }

    for (int i = 1; i <= s.length; i++) {
      for (int j = 1; j <= t.length; j++) {
        final cost = s[i - 1] == t[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce(math.min);
      }
    }

    return dp[s.length][t.length];
  }

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
        if (l['line_id'] == lineId) return l['color_final'];
      }
    }
    final rand = math.Random(lineId.hashCode);
    return Color.fromARGB(255, 100 + rand.nextInt(155), 100 + rand.nextInt(155), 100 + rand.nextInt(155));
  }

  void _toggleLineTrajectory(String lineId) => setState(() {
        _displayedLines.contains(lineId)
            ? _displayedLines.remove(lineId)
            : _displayedLines.add(lineId);
      });

  Widget _buildMapControls() => Positioned(
        bottom: 20,
        right: 20,
        child: Column(children: [
          FloatingActionButton.small(heroTag: 'zoom_in', child: const Icon(Icons.add), onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
          const SizedBox(height: 8),
          FloatingActionButton.small(heroTag: 'zoom_out', child: const Icon(Icons.remove), onPressed: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
        ]),
      );

  String _calculateTrajectoryDistance(List<LatLng> pts) {
    if (pts.length < 2) return '0 m';
    var dist = 0.0;
    for (var i = 0; i < pts.length - 1; i++) {
      dist += const Distance().as(LengthUnit.Meter, pts[i], pts[i + 1]);
    }
    return dist < 1000 ? '${dist.toStringAsFixed(0)} m' : '${(dist / 1000).toStringAsFixed(1)} km';
  }

  MarkerLayer _buildTrajectoryMarkers() {
    final markers = <Marker>[];
    for (final id in _displayedLines) {
      final traj = _lineTrajectories[id] ?? [];
      if (traj.isEmpty) continue;
      markers.addAll([
        Marker(width: 24, height: 24, point: traj.first, child: _endpoint(_getLineColor(id), Icons.play_arrow)),
        Marker(width: 24, height: 24, point: traj.last, child: _endpoint(_getLineColor(id), Icons.stop)),
      ]);
    }
    return MarkerLayer(markers: markers);
  }

  Widget _endpoint(Color c, IconData ic) => Container(
        decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
        child: Icon(ic, color: Colors.white, size: 12),
      );

  List<Polyline> _buildPolylineLayers() => _displayedLines
      .where((id) => _lineTrajectories[id]?.isNotEmpty ?? false)
      .map((id) => Polyline(points: _lineTrajectories[id]!, strokeWidth: 4, color: _getLineColor(id)))
      .toList();

  @override
Widget build(BuildContext context) {
    final stops = stopsMap.values.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Arrêts à proximité', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: userLocation ?? const LatLng(35.5667, -5.3667),
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                subdomains: ['a', 'b', 'c', 'd'],
              ),
              if (_userMarker != null) MarkerLayer(markers: [_userMarker!]),
              MarkerLayer(
                markers: stops.map((s) {
                  final sel = selectedStop != null &&
                      s['name'] == selectedStop!['name'] &&
                      s['lat'] == selectedStop!['lat'] &&
                      s['lon'] == selectedStop!['lon'];
                  return Marker(
                    point: LatLng(s['lat'], s['lon']),
                    width: sel ? 40 : 30,
                    height: sel ? 40 : 30,
                    child: GestureDetector(
                      onTap: () => _selectStop(s),
                      child: SvgPicture.asset('assets/icons/bus.svg', colorFilter: const ColorFilter.mode(Colors.blue, BlendMode.srcIn)),
                    ),
                  );
                }).toList(),
              ),
              PolylineLayer(
                polylines: _displayedLines
                    .where((id) => _lineTrajectories[id]?.isNotEmpty ?? false)
                    .map((id) => Polyline(points: _lineTrajectories[id]!, strokeWidth: 4, color: _getLineColor(id)))
                    .toList(),
              )
            ],
          ),
          if (loadingStops)
            const Positioned(
              top: 10,
              right: 10,
              child: Card(color: Colors.white70, child: Padding(padding: EdgeInsets.all(6), child: Text('Chargement des arrêts…'))),
            ),
          if (locationPermissionDenied)
            Positioned(
              top: 60,
              left: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(10)),
                child: const Text('Géolocalisation refusée. Entrez votre emplacement manuellement.', style: TextStyle(color: Colors.red), textAlign: TextAlign.center),
              ),
            ),
          _buildMapControls(),
        ],
      ),
    );
  }
List<Map<String, dynamic>> removeDuplicateLinesByRouteName(List<Map<String, dynamic>> stopsList) {
  for (var stop in stopsList) {
    final lines = stop['lines'] as List;
    final seenRouteNames = <String>{};

    // Remove duplicates by route_name
    final uniqueLines = lines.where((line) {
      final routeName = line['route_name'];
      if (seenRouteNames.contains(routeName)) {
        return false;
      } else {
        seenRouteNames.add(routeName);
        return true;
      }
    }).toList();

    stop['lines'] = uniqueLines;
  }

  return stopsList;
}

void _selectStop(Map<String, dynamic> stop) {
    setState(() => selectedStop = stop);

    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final lines = stop['lines'] as List<dynamic>;
        final ids = <String>{};
        final uniqueLines = lines.where((l) => ids.add(l['line_id'])).toList();

        return SizedBox(
          height: 400,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Lignes desservant cet arrêt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: uniqueLines.length,
                  itemBuilder: (context, index) {
                    final line = uniqueLines[index];
                    final lineId = line['line_id'];
                    return ListTile(
                      leading: Icon(Icons.directions_bus, color: line['color_final']),
                      title: Text(line['route_name'] ?? 'Ligne $lineId'),
                      trailing: IconButton(
                        icon: Icon(_displayedLines.contains(lineId) ? Icons.visibility_off : Icons.visibility),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _toggleLineTrajectory(lineId);
                        },
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BusLineDetailsScreen(lineData: line),
                          ),
                        );
                      },
                    );
                  },
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
