
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

// --- Data Models for Tobis API ---

class TobisRoute {
  final int lineId;
  final String routeName;
  final String startStopArrivalTime;
  final String arrivalTime;
  final int rideEtaMin;
  final List<TobisStop> stops;

  TobisRoute({
    required this.lineId,
    required this.routeName,
    required this.startStopArrivalTime,
    required this.arrivalTime,
    required this.rideEtaMin,
    required this.stops,
  });

  factory TobisRoute.fromJson(Map<String, dynamic> json) {
    var stopsList = json['stops'] as List<dynamic>? ?? [];
    List<TobisStop> stops = stopsList.map((i) => TobisStop.fromJson(i)).toList();

    // FIX: The true arrival time is the time of the last stop.
    String finalArrivalTime = (stops.isNotEmpty) ? stops.last.time : 'N/A';

    return TobisRoute(
      lineId: json['line_id'],
      routeName: json['route_name'],
      startStopArrivalTime: json['start_stop_arrival_time'] ?? 'N/A',
      arrivalTime: finalArrivalTime, // Use the corrected arrival time
      rideEtaMin: json['ride_eta_min'] ?? 0,
      stops: stops,
    );
  }
}

class TobisStop {
  final int id;
  final String name;
  final int etaMinFromStart;
  final String time;

  TobisStop({
    required this.id,
    required this.name,
    required this.etaMinFromStart,
    required this.time,
  });

  factory TobisStop.fromJson(Map<String, dynamic> json) {
    return TobisStop(
      id: json['id'],
      name: json['name'],
      etaMinFromStart: json['eta_min_from_start'],
      time: json['time'],
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
  final int _currentIndex = 0;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error searching for routes: $e")),
      );
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

  void _onTabTapped(int index) {
    if (index == 1) {
      Navigator.pushReplacementNamed(context, '/stations');
    } else if (index == 2) {
      Navigator.pushReplacementNamed(context, '/lines');
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!isLoading && tobisRoutes != null)
              Expanded(child: _buildTobisResults()),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Itinéraires'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Stations'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Lignes'),
        ],
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

// --- NEW WIDGET --- 
class TobisRouteCard extends StatefulWidget {
  final TobisRoute route;
  final Position startPosition;
  final Map<String, dynamic> destination;

  const TobisRouteCard({Key? key, required this.route, required this.startPosition, required this.destination}) : super(key: key);

  @override
  _TobisRouteCardState createState() => _TobisRouteCardState();
}

class _TobisRouteCardState extends State<TobisRouteCard> {
  bool _isExpanded = false;

  Color _getColorForLine(String lineName) {
    final hash = lineName.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromRGBO(r, g, b, 1).withOpacity(0.8);
  }

  String _calculateDistance(){
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

    if (startTimeString == 'N/A' || endTimeString == 'N/A') {
      return '-- min';
    }

    try {
        final startParts = startTimeString.split(':').map(int.parse).toList();
        final endParts = endTimeString.split(':').map(int.parse).toList();

        final start = DateTime(2023, 1, 1, startParts[0], startParts[1]);
        final end = DateTime(2023, 1, 1, endParts[0], endParts[1]);

        Duration diff = end.difference(start);
        if (diff.isNegative) {
          diff += const Duration(hours: 24); 
        }
        
        return "${diff.inMinutes} min";
    } catch (e) {
        return '-- min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = widget.route;
    final lineColor = _getColorForLine(route.routeName);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      color: Colors.deepPurple[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.directions_bus, color: Colors.deepPurple[700]),
                const SizedBox(width: 8),
                Text("${route.startStopArrivalTime} → ${route.arrivalTime}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Text("(${_calculateDuration()})", style: TextStyle(fontSize: 14, color: Colors.deepPurple[800], fontWeight: FontWeight.w500)),
                const Spacer(),
                 Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple[100],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_calculateDistance(), style: TextStyle(color: Colors.deepPurple[800], fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.blue),
                const SizedBox(width: 4), 
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(route.routeName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                const Icon(Icons.location_on, color: Colors.red),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => setState(() => _isExpanded = !_isExpanded),
              child: Row(
                children: [
                  Icon(_isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: Colors.blue),
                  const SizedBox(width: 4),
                  Text(_isExpanded ? "Masquer les détails" : "Détails", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            if (_isExpanded)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailRow(Icons.directions_walk, "Marcher jusqu'à ${route.stops.first.name}"),
                    _buildDetailRow(Icons.directions_bus, "Bus ligne ${route.routeName} vers ${widget.destination['name']}"),
                    const SizedBox(height: 8),
                    ...route.stops.map((stop) => Padding(
                      padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
                      child: Text("• ${stop.name} à ${stop.time}", style: TextStyle(color: Colors.grey[700])),
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
