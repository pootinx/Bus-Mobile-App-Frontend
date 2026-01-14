import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bus_app/core/services/google_directions_service.dart';
import 'package:bus_app/core/services/google_places_service.dart';
import 'package:bus_app/core/services/location_service.dart';
import 'package:bus_app/features/t_pass/presentation/pages/t_pass_page.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_app/features/map/presentation/pages/route_details_page.dart';
import 'package:bus_app/core/utils/permission_handler.dart';
import 'package:bus_app/shared/models/directions_response.dart' as dr;
import 'package:bus_app/shared/widgets/route_summary_card.dart';

class SearchPage extends StatefulWidget {
  final String? initialQuery;
  const SearchPage({super.key, this.initialQuery});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
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
    
    if (widget.initialQuery != null) {
      _arriveeController.text = widget.initialQuery!;
    }

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
    final granted = await PermissionHandler.handleLocationPermission(context);
    if (mounted) {
      setState(() {
        _isLocationPermissionGranted = granted;
      });
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
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.blue,
      statusBarIconBrightness: Brightness.light,
    ));

    return Material(
      color: Colors.blue[50],
      child: GestureDetector(
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
    if (_directionsResult == null) return const SizedBox.shrink();

    final directions = dr.DirectionsResponse.fromJson(_directionsResult!);
    
    // Filter routes that have bus steps
    final busRoutes = directions.routes.where((route) {
      return route.legs.any((leg) => leg.steps.any((step) => 
        step.travelMode == 'TRANSIT' && 
        step.transitDetails?.line.vehicle.type == 'BUS'));
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
              return RouteSummaryCard(route: busRoutes[index]);
            },
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
