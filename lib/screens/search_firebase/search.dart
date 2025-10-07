
import 'dart:async';
import 'dart:math';

import 'package:bus_app/services/google_directions_service.dart';
import 'package:bus_app/services/google_places_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'route_details_screen.dart';

class SearchRouteScreen extends StatefulWidget {
  const SearchRouteScreen({super.key});

  @override
  State<SearchRouteScreen> createState() => _SearchRouteScreenState();
}

class _SearchRouteScreenState extends State<SearchRouteScreen> {
  final TextEditingController _departController = TextEditingController();
  final TextEditingController _arriveeController = TextEditingController();
  final FocusNode _departFocusNode = FocusNode();
  final FocusNode _arriveeFocusNode = FocusNode();

  final GooglePlacesService _placesService = GooglePlacesService();
  final GoogleDirectionsService _directionsService = GoogleDirectionsService();

  List<Map<String, String>> _departSuggestions = [];
  List<Map<String, String>> _arriveeSuggestions = [];
  
  bool _showDepartSuggestions = false;
  bool _showArriveeSuggestions = false;

  LatLng? _startLatLng;
  LatLng? _destinationLatLng;

  Map<String, dynamic>? _directionsResult;
  bool _isLoading = false;
  
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _departFocusNode.addListener(() {
      setState(() {
        _showDepartSuggestions = _departFocusNode.hasFocus;
      });
    });
    _arriveeFocusNode.addListener(() {
      setState(() {
        _showArriveeSuggestions = _arriveeFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _departController.dispose();
    _arriveeController.dispose();
    _departFocusNode.dispose();
    _arriveeFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onInputChanged(String input, bool isDepart) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (input.length > 2) {
        try {
          final suggestions = await _placesService.getAutocomplete(input);
          setState(() {
            if (isDepart) {
              _departSuggestions = suggestions;
            } else {
              _arriveeSuggestions = suggestions;
            }
          });
        } catch (e) {
          print("Autocomplete error: $e");
        }
      } else {
        setState(() {
          if (isDepart) _departSuggestions = [];
          else _arriveeSuggestions = [];
        });
      }
    });
  }

  Future<void> _onSuggestionSelected(Map<String, String> suggestion, bool isDepart) async {
    final placeId = suggestion['place_id']!;
    final placeText = suggestion['description']!;
    
    try {
      final details = await _placesService.getPlaceDetails(placeId);
      final location = details['location'];
      final lat = location['latitude'];
      final lng = location['longitude'];

      setState(() {
        if (isDepart) {
          _departController.text = placeText;
          _startLatLng = LatLng(lat, lng);
          _departSuggestions = [];
          _departFocusNode.unfocus();
        } else {
          _arriveeController.text = placeText;
          _destinationLatLng = LatLng(lat, lng);
          _arriveeSuggestions = [];
          _arriveeFocusNode.unfocus();
        }
      });
    } catch (e) {
      print("Place details error: $e");
    }
  }

  void _swapLocations() {
    final tempText = _departController.text;
    final tempLatLng = _startLatLng;

    setState(() {
      _departController.text = _arriveeController.text;
      _startLatLng = _destinationLatLng;
      
      _arriveeController.text = tempText;
      _destinationLatLng = tempLatLng;
    });
  }

  Future<void> _searchRoutes() async {
    _departFocusNode.unfocus();
    _arriveeFocusNode.unfocus();

    if (_startLatLng == null || _destinationLatLng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid start and destination.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _directionsResult = null;
    });

    try {
      final result = await _directionsService.getBusDirections(_startLatLng!, _destinationLatLng!);
      setState(() {
        _directionsResult = result;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for routes: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setCurrentLocationAsDeparture() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied.");
      }
      if (permission == LocationPermission.denied) {
        throw Exception("Location permissions are denied.");
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _startLatLng = LatLng(position.latitude, position.longitude);
        _departController.text = "Current location";
        _departFocusNode.unfocus();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error getting location: $e')),
      );
    }
  }

  Color _getColorForLine(String lineName) {
    final hash = lineName.hashCode;
    final r = (hash & 0xFF0000) >> 16;
    final g = (hash & 0x00FF00) >> 8;
    final b = hash & 0x0000FF;
    return Color.fromRGBO(r, g, b, 1);
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Search Route"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: GestureDetector(
        onTap: () {
          _departFocusNode.unfocus();
          _arriveeFocusNode.unfocus();
        },
        child: Column(
          children: [
            _buildSearchCard(),
            Expanded(
              child: Stack(
                children: [
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _buildResults(),
                  if (_showDepartSuggestions && _departSuggestions.isNotEmpty)
                    _buildSuggestionsList(isDepart: true),
                  if (_showArriveeSuggestions && _arriveeSuggestions.isNotEmpty)
                    _buildSuggestionsList(isDepart: false),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestionsList({required bool isDepart}) {
    final suggestions = isDepart ? _departSuggestions : _arriveeSuggestions;
    final topPosition = isDepart ? 60.0 : 125.0;

    return Positioned(
      top: 0,
      left: 15,
      right: 15,
      child: Material(
        elevation: 4.0,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          constraints: const BoxConstraints(maxHeight: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: suggestions.length,
            itemBuilder: (context, index) {
              final suggestion = suggestions[index];
              return ListTile(
                title: Text(suggestion['description']!),
                onTap: () => _onSuggestionSelected(suggestion, isDepart),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSearchCard() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Column(
                children: [
                  _buildSearchTextField(
                    controller: _departController,
                    focusNode: _departFocusNode,
                    hint: 'From',
                    icon: Icons.gps_fixed,
                    isDepart: true,
                  ),
                  const SizedBox(height: 16),
                  _buildSearchTextField(
                    controller: _arriveeController,
                    focusNode: _arriveeFocusNode,
                    hint: 'To',
                    icon: Icons.location_on,
                    isDepart: false,
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300)
                ),
                child: IconButton(
                  icon: const Icon(Icons.swap_vert, color: Colors.blue),
                  onPressed: _swapLocations,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool isDepart,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (input) => _onInputChanged(input, isDepart),
      decoration: InputDecoration(
        labelText: hint,
        labelStyle: const TextStyle(color: Colors.grey),
        prefixIcon: Icon(icon, color: Colors.grey),
        suffixIcon: isDepart
            ? IconButton(
                icon: const Icon(Icons.my_location, color: Colors.orange),
                onPressed: _setCurrentLocationAsDeparture,
              )
            : IconButton(
                icon: const Icon(Icons.search, color: Colors.blue),
                onPressed: _searchRoutes,
              ),
        border: InputBorder.none,
        filled: true,
        fillColor: Colors.grey[50],
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildResults() {
    if (_directionsResult == null) {
      return const Center(child: Text("Enter a departure and destination to see the routes."));
    }

    final allRoutes = _directionsResult!['routes'] as List;
    final busRoutes = allRoutes.where((route) {
      final legs = route['legs'] as List;
      if (legs.isEmpty) return false;
      final steps = legs[0]['steps'] as List;
      return steps.any((step) =>
          step['travel_mode'] == 'TRANSIT' &&
          step['transit_details'] != null &&
          step['transit_details']['line'] != null &&
          step['transit_details']['line']['vehicle'] != null &&
          step['transit_details']['line']['vehicle']['type'] == 'BUS');
    }).toList();

    if (busRoutes.isEmpty) {
      return const Center(child: Text("No bus routes available."));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: busRoutes.length,
      itemBuilder: (context, index) {
        final route = busRoutes[index];
        return _buildRouteCard(route);
      },
    );
  }

  Widget _buildRouteCard(Map<String, dynamic> route) {
    final leg = route['legs'][0];
    final totalDuration = leg['duration']['text'];
    final departureTime = leg['departure_time']['text'];
    final arrivalTime = leg['arrival_time']['text'];

    final steps = leg['steps'] as List;
    final busSteps = steps.where((step) =>
        step['travel_mode'] == 'TRANSIT' &&
        step['transit_details']['line']['vehicle']['type'] == 'BUS').toList();

    if (busSteps.isEmpty) {
      return const SizedBox.shrink(); 
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$departureTime → $arrivalTime',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  totalDuration,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.purple),
                ),
              ],
            ),
            const Divider(height: 20),
            ..._buildBusStepWidgets(busSteps),
            const SizedBox(height: 10),
             GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RouteDetailsScreen(routeData: route),
                  ),
                );
              },
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text('Details', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                  Icon(Icons.arrow_forward_ios, color: Colors.blue, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBusStepWidgets(List<dynamic> busSteps) {
    final widgets = <Widget>[];
    for (int i = 0; i < busSteps.length; i++) {
        final step = busSteps[i];
        final transitDetails = step['transit_details'];
        final line = transitDetails['line'];
        final lineName = line['short_name'] ?? line['name'] ?? 'N/A';
        final departureStop = transitDetails['departure_stop']['name'];
        final arrivalStop = transitDetails['arrival_stop']['name'];
        final numStops = transitDetails['num_stops'].toString();
        final duration = step['duration']['text'];
        final departureTime = transitDetails['departure_time']['text'];
        final arrivalTime = transitDetails['arrival_time']['text'];

        widgets.add(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getColorForLine(lineName),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        lineName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$departureStop → $arrivalStop',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4),
                  child: Text(
                    '$duration ($numStops stops) | $departureTime - $arrivalTime',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
              ],
            )
        );

        if (i < busSteps.length - 1) {
            widgets.add(
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.more_vert, color: Colors.grey, size: 18),
                      const SizedBox(width: 8),
                      Text("Transfer", style: TextStyle(color: Colors.grey[600], fontStyle: FontStyle.italic)),
                    ],
                  ),
                )
            );
        }
    }
    return widgets;
  }
}
