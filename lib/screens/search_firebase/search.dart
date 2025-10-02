import 'dart:convert';
import 'package:bus_app/screens/search_firebase/route_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

// --- Updated Data Models ---

class TobisRoute {
  final int lineId;
  final String routeName;
  final String startStopArrivalTime;
  final String arrivalTime;
  final int rideEtaMin;
  final List<TobisStop> stops;
  final String? polyline;
  final String? color;

  TobisRoute({
    required this.lineId,
    required this.routeName,
    required this.startStopArrivalTime,
    required this.arrivalTime,
    required this.rideEtaMin,
    required this.stops,
    this.polyline,
    this.color,
  });

  factory TobisRoute.fromJson(Map<String, dynamic> json) {
    var stopsList = json['stops'] as List<dynamic>? ?? [];
    List<TobisStop> stops = stopsList.map((i) => TobisStop.fromJson(i)).toList();
    String finalArrivalTime = (stops.isNotEmpty) ? stops.last.time : 'N/A';

    return TobisRoute(
      lineId: json['line_id'],
      routeName: json['route_name'],
      startStopArrivalTime: json['start_stop_arrival_time'] ?? 'N/A',
      arrivalTime: finalArrivalTime,
      rideEtaMin: json['ride_eta_min'] ?? 0,
      stops: stops,
      polyline: json['polyline'],
      color: json['color'],
    );
  }
}

class TobisStop {
  final int id;
  final String name;
  final int etaMinFromStart;
  final String time;
  final double lat;
  final double lon;

  TobisStop({
    required this.id,
    required this.name,
    required this.etaMinFromStart,
    required this.time,
    required this.lat,
    required this.lon,
  });

  factory TobisStop.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse a value that could be a num or a String
    double _parseDouble(dynamic value) {
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        return double.tryParse(value) ?? 0.0;
      }
      return 0.0;
    }

    return TobisStop(
      id: json['id'],
      name: json['name'],
      etaMinFromStart: json['eta_min_from_start'],
      time: json['time'],
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
    );
  }
}


class SearchRouteScreenV1 extends StatefulWidget {
  const SearchRouteScreenV1({super.key});

  @override
  State<SearchRouteScreenV1> createState() => _SearchRouteScreenV1State();
}

class _SearchRouteScreenV1State extends State<SearchRouteScreenV1> {
  final TextEditingController departController = TextEditingController();
  final TextEditingController arriveeController = TextEditingController();
  
  List<TobisRoute>? tobisRoutes;
  Position? _startPosition;
  Map<String, dynamic>? _destination;

  bool isLoading = false;
  bool _hasInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      arriveeController.text = args;
       if (_hasInitialized) {
        searchRoutes();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
      }
    });
  }

  Future<Position> _getCoordinatesFromAddress(String address) async {
      List<Location> locations = await locationFromAddress(address);
      if (locations.isEmpty) {
        throw Exception("Address not found: $address");
      }
      final loc = locations.first;
      return Position(latitude: loc.latitude, longitude: loc.longitude, timestamp: DateTime.now(), accuracy: 100, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
  }


  Future<void> searchRoutes() async {
    final startAddress = departController.text.trim();
    final destinationAddress = arriveeController.text.trim();

    if (destinationAddress.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a destination')),
        );
      }
      return;
    }

    setState(() {
      isLoading = true;
      tobisRoutes = null;
      _startPosition = null;
      _destination = null;
    });

    try {
      Position startPosition;

      if (startAddress.isNotEmpty) {
        startPosition = await _getCoordinatesFromAddress(startAddress);
      } else {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
            throw Exception("Location permission is required if you don't enter a starting address.");
          }
          startPosition = await Geolocator.getCurrentPosition();
          if (mounted) {
             List<Placemark> placemarks = await placemarkFromCoordinates(startPosition.latitude, startPosition.longitude);
             if(placemarks.isNotEmpty){
                final place = placemarks.first;
                departController.text = "${place.street}, ${place.locality}";
             }
          }
      }

      final baseUrl = "https://tobis-backend.onrender.com/itinerary/routes";
      final params = {
        'dest_add': destinationAddress,
        'start_lat': startPosition.latitude.toString(),
        'start_lon': startPosition.longitude.toString(),
        'limit': '5',
        'city_id': '1', 
      };
      final uri = Uri.parse(baseUrl).replace(queryParameters: params);
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final lines = data['lines'] as List;
        final results = lines.map((line) => TobisRoute.fromJson(line)).toList();

        setState(() {
          tobisRoutes = results;
          _startPosition = startPosition;
          _destination = data['destination'];
          isLoading = false;
        });

        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No routes found for the given locations")),
          );
        }
      } else {
        throw Exception('Failed to load routes: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error searching for routes: $e")),
        );
      }
    }
  }
  
  Future<void> setCurrentLocationAsDeparture() async {
    try {
      setState(() { isLoading = true; });
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception("Location permission denied");
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          departController.text = "${place.street}, ${place.locality}";
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { isLoading = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error getting location: $e')),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Rechercher un itinéraire"),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!isLoading && tobisRoutes != null)
              _buildTobisResults(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
     return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -5)],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // From field
          Row(
            children: [
              const Icon(Icons.gps_fixed, color: Colors.grey),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("From", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    TextField(
                      controller: departController,
                      decoration: const InputDecoration(
                        hintText: "Current Location (or type address)",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
               IconButton(
                icon: const Icon(Icons.my_location, color: Colors.orange),
                onPressed: setCurrentLocationAsDeparture,
              ),
            ],
          ),
          // Divider and Swap button
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Material(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        final temp = departController.text;
                        setState(() {
                          departController.text = arriveeController.text;
                          arriveeController.text = temp;
                        });
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.swap_vert, color: Colors.blue, size: 20),
                      ),
                    ),
                  ),
                ),
                 const Expanded(child: Divider()),
              ],
            ),
          ),
          // To field
          Row(
            children: [
              const Icon(Icons.location_on, color: Colors.red),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("To", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    TextField(
                      controller: arriveeController,
                      decoration: const InputDecoration(
                        hintText: "Where are you going?",
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                       onSubmitted: (_) => searchRoutes(),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.search, color: Colors.blue),
                onPressed: searchRoutes,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTobisResults() {
    if (tobisRoutes == null || tobisRoutes!.isEmpty) {
      return const Center(
        child: Text("No routes found", style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: tobisRoutes!.length,
      itemBuilder: (context, index) {
        final route = tobisRoutes![index];
        return TobisRouteCard(
          route: route,
          startPosition: _startPosition!,
          destination: _destination!,
          ); 
      },
    );
  }

  @override
  void dispose() {
    departController.dispose();
    arriveeController.dispose();
    super.dispose();
  }
}


class TobisRouteCard extends StatefulWidget {
  final TobisRoute route;
  final Position startPosition;
  final Map<String, dynamic> destination;

  const TobisRouteCard({
    Key? key,
    required this.route,
    required this.startPosition,
    required this.destination,
  }) : super(key: key);

  @override
  _TobisRouteCardState createState() => _TobisRouteCardState();
}

class _TobisRouteCardState extends State<TobisRouteCard> {
  bool _isExpanded = false;

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }
  
  String _calculateDistance() {
    final distance = Geolocator.distanceBetween(
      widget.startPosition.latitude,
      widget.startPosition.longitude,
      widget.destination['lat'],
      widget.destination['lon'],
    );
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String _calculateDuration() {
    final startTimeString = widget.route.startStopArrivalTime;
    final endTimeString = widget.route.arrivalTime;

    if (startTimeString == 'N/A' || endTimeString == 'N/A') return '-- min';

    try {
      final startParts = startTimeString.split(':').map(int.parse).toList();
      final endParts = endTimeString.split(':').map(int.parse).toList();
      final start = DateTime(2023, 1, 1, startParts[0], startParts[1]);
      final end = DateTime(2023, 1, 1, endParts[0], endParts[1]);
      Duration diff = end.difference(start);
      if (diff.isNegative) diff += const Duration(hours: 24);
      return "${diff.inMinutes} min";
    } catch (e) {
      return '-- min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final lineColor = _hexToColor(route.color ?? '#FFA500');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: const Color(0xFFF3EFFF),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailsScreen(route: route),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(Icons.directions_bus, color: Colors.deepPurple.shade400, size: 22),
                      const SizedBox(width: 8),
                      Text(
                        '${route.startStopArrivalTime} → ${route.arrivalTime}',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      Text('(${_calculateDuration()})', style: const TextStyle(fontSize: 15, color: Colors.black54)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.deepPurple.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_calculateDistance(), style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.deepPurple.shade800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.directions_walk, color: Colors.blue, size: 22),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: lineColor, borderRadius: BorderRadius.circular(6)),
                        child: Text(route.routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.grey, size: 16),
                      const Icon(Icons.location_pin, color: Colors.red, size: 22),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1, indent: 12, endIndent: 12),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Icon(_isExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 4),
                    Text(
                      _isExpanded ? "Masquer les détails" : "Détails",
                      style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    _buildDetailRow(Icons.directions_walk, "Walk to ${route.stops.first.name}"),
                    _buildDetailRow(Icons.directions_bus, "Take bus line ${route.routeName}"),
                    const SizedBox(height: 8),
                    ...route.stops.map((stop) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                      child: Text("• ${stop.name} at ${stop.time}", style: TextStyle(color: Colors.grey[700])),
                    )).toList(),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: Colors.blue, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15))),
        ],
      ),
    );
  }
}
