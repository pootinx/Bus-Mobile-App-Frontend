
import 'dart:async';
import 'dart:convert';
import 'package:bus_app/services/google_directions_service.dart';
import 'package:bus_app/services/google_places_service.dart';
import 'package:bus_app/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final LocationService _locationService = LocationService();

  List<Map<String, String>> _departSuggestions = [];
  List<Map<String, String>> _arriveeSuggestions = [];

  bool _showDepartSuggestions = false;
  bool _showArriveeSuggestions = false;

  LatLng? _startLatLng;
  LatLng? _destinationLatLng;

  Map<String, dynamic>? _directionsResult;
  bool _isLoading = false;
  bool _isLocationPermissionGranted = false;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _loadSearchFromPrefs();
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

  Future<void> _checkLocationPermission() async {
    try {
      await _locationService.getCurrentLocation(); // This will trigger the permission request
      if (mounted) {
        setState(() {
          _isLocationPermissionGranted = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLocationPermissionGranted = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to use the "Current Location" feature.')),
        );
      }
    }
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

  Future<void> _saveSearchToPrefs() async {
    if (_startLatLng == null || _destinationLatLng == null || _directionsResult == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchData = {
        'startText': _departController.text,
        'endText': _arriveeController.text,
        'startLat': _startLatLng!.latitude,
        'startLng': _startLatLng!.longitude,
        'endLat': _destinationLatLng!.latitude,
        'endLng': _destinationLatLng!.longitude,
        'directionsResult': jsonEncode(_directionsResult),
      };
      await prefs.setString('lastSearch', jsonEncode(searchData));
    } catch (e) {
      print("Error saving search to prefs: $e");
    }
  }

  Future<void> _loadSearchFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSearchString = prefs.getString('lastSearch');
      if (lastSearchString != null) {
        final searchData = jsonDecode(lastSearchString);
        if (!mounted) return;
        setState(() {
          _departController.text = searchData['startText'] ?? '';
          _arriveeController.text = searchData['endText'] ?? '';
          _startLatLng = LatLng(searchData['startLat'], searchData['startLng']);
          _destinationLatLng = LatLng(searchData['endLat'], searchData['endLng']);
          _directionsResult = jsonDecode(searchData['directionsResult']);
        });
      }
    } catch (e) {
      print("Error loading search from prefs: $e");
    }
  }

  void _onInputChanged(String input, bool isDepart) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (input.length > 2) {
        try {
          final suggestions = await _placesService.getAutocomplete(input);
          if (!mounted) return;
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
        if (!mounted) return;
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

      if (!mounted) return;
      setState(() {
        if (isDepart) {
          _departController.text = placeText;
          _startLatLng = LatLng(lat, lng);
          _departSuggestions = [];
          _showDepartSuggestions = false;
          _departFocusNode.unfocus();
        } else {
          _arriveeController.text = placeText;
          _destinationLatLng = LatLng(lat, lng);
          _arriveeSuggestions = [];
          _showArriveeSuggestions = false;
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
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _directionsResult = result;
      });
      await _saveSearchToPrefs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching for routes: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _setCurrentLocationAsDeparture() async {
    if (!_isLocationPermissionGranted) {
      _checkLocationPermission(); // Re-check permission if not granted
      return;
    }

    try {
      final latLng = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _startLatLng = latLng;
        _departController.text = "Current location";
        _departFocusNode.unfocus();
      });
    } catch (e) {
      if (!mounted) return;
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
      backgroundColor: Colors.blue[50],
      body: GestureDetector(
        onTap: () {
          _departFocusNode.unfocus();
          _arriveeFocusNode.unfocus();
          setState(() {
            _showDepartSuggestions = false;
            _showArriveeSuggestions = false;
          });
        },
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              _buildSearchSection(),
              _isLoading
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ))
                  : _buildResults(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 50, 20, 70),
      decoration: const BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tobis',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.notifications, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Bienvenu!',
            style: TextStyle(color: Colors.white,fontFamily: 'Poppins', fontSize: 24,fontWeight: FontWeight.bold,),
          ),
          const Text(
            'Trouvez facilement le meilleur itinéraire en bus pour vousdéplacer dans la ville',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontFamily: 'Poppins',

            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchSection() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Container(
            margin: const EdgeInsets.only(top: 20),
            padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 15.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 3,
                  blurRadius: 10,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildInputCard(
                  controller: _departController,
                  focusNode: _departFocusNode,
                  hint: 'From',
                  isDepart: true,
                ),
                if (_showDepartSuggestions && _departSuggestions.isNotEmpty)
                  _buildSuggestionsList(isDepart: true),

                Stack(
                  alignment: Alignment.center,
                  children: [
                    const Divider(),
                    InkWell(
                      onTap: _swapLocations,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.blue.shade100)
                        ),
                        child: const Icon(Icons.swap_vert, color: Colors.blue, size: 24),
                      ),
                    ),
                  ],
                ),

                _buildInputCard(
                  controller: _arriveeController,
                  focusNode: _arriveeFocusNode,
                  hint: 'To',
                  isDepart: false,
                ),
                if (_showArriveeSuggestions && _arriveeSuggestions.isNotEmpty)
                  _buildSuggestionsList(isDepart: false),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required bool isDepart,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: (input) => _onInputChanged(input, isDepart),
      decoration: InputDecoration(
        hintText: hint,
        border: InputBorder.none,
        suffixIcon: isDepart
            ? IconButton(
                icon: Icon(Icons.gps_not_fixed, color: _isLocationPermissionGranted ? Colors.orange : Colors.grey),
                onPressed: _setCurrentLocationAsDeparture,
              )
            : InkWell(
                onTap: _searchRoutes,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade700],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight
                    )
                  ),
                  child: const Icon(Icons.search, color: Colors.white, size: 24),
                ),
            )
      ),
    );
  }

  Widget _buildSuggestionsList({required bool isDepart}) {
    final suggestions = isDepart ? _departSuggestions : _arriveeSuggestions;

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
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
    );
  }

  Widget _buildResults() {
    if (_directionsResult == null) {
      return Container();
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
      return const Center(child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Text("No bus routes available.", style: TextStyle(fontSize: 16, color: Colors.grey)),
      ));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Available Routes", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: busRoutes.length,
            itemBuilder: (context, index) {
              final route = busRoutes[index];
              return _buildRouteCard(route);
            },
          ),
        ],
      ),
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      elevation: 3,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RouteDetailsScreen(routeData: route),
            ),
          );
        },
        borderRadius: BorderRadius.circular(15),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                  ),
                ],
              ),
              const Divider(height: 20),
              ..._buildBusStepWidgets(busSteps),
            ],
          ),
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

        widgets.add(
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
