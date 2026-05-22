import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bus_app/core/services/google_directions_service.dart';
import 'package:bus_app/core/services/google_places_service.dart';
import 'package:bus_app/core/services/location_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bus_app/core/utils/permission_handler.dart';
import 'package:bus_app/shared/models/directions_response.dart' as dr;
import 'package:bus_app/shared/widgets/route_summary_card.dart';
import 'package:bus_app/l10n/app_localizations.dart';
import 'package:shimmer/shimmer.dart';

class DetailedSearchPage extends StatefulWidget {
  final String? initialQuery;
  final LatLng? initialDestinationLatLng;
  final String? initialDestinationName;

  const DetailedSearchPage({
    super.key,
    this.initialQuery,
    this.initialDestinationLatLng,
    this.initialDestinationName,
  });

  @override
  State<DetailedSearchPage> createState() => _DetailedSearchPageState();
}

class _DetailedSearchPageState extends State<DetailedSearchPage> {
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
    debugPrint("DetailedSearchPage: initState. initialDestinationLatLng: ${widget.initialDestinationLatLng}");
    _checkLocationPermission();
    
    if (widget.initialDestinationLatLng != null || widget.initialQuery != null) {
      if (widget.initialDestinationLatLng != null) {
        debugPrint("DetailedSearchPage: Initial destination provided. Triggering auto-location.");
        _destinationLatLng = widget.initialDestinationLatLng;
        _arriveeController.text = widget.initialDestinationName ?? '';
      } else if (widget.initialQuery != null) {
        _arriveeController.text = widget.initialQuery!;
      }

      _setCurrentLocationAsDeparture().then((_) {
        if (_destinationLatLng != null) {
          _searchRoutes();
        }
      });
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
      debugPrint("Error saving search to prefs: $e");
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
          debugPrint("Autocomplete error: $e");
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
      debugPrint("Place details error: $e");
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
    FocusScope.of(context).unfocus();

    if (_startLatLng == null || _destinationLatLng == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un départ et une destination valides.')),
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
        SnackBar(content: Text('Erreur lors de la recherche d\'itinéraires : $e')),
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
    debugPrint("DetailedSearchPage: _setCurrentLocationAsDeparture invoked. Permission granted: $_isLocationPermissionGranted");
    if (!_isLocationPermissionGranted) {
      debugPrint("DetailedSearchPage: Requesting permission...");
      await _checkLocationPermission();
      // Wait briefly for state to update
      await Future.delayed(const Duration(milliseconds: 100));
      if (!_isLocationPermissionGranted) {
        debugPrint("DetailedSearchPage: Permission denied. Aborting auto-location.");
        return;
      }
    }

    try {
      debugPrint("DetailedSearchPage: Fetching current location...");
      final latLng = await _locationService.getCurrentLocation();
      debugPrint("DetailedSearchPage: Location fetched: $latLng");
      if (!mounted) return;
      setState(() {
        _startLatLng = latLng;
        _departController.text = "Ma position actuelle";
        _departFocusNode.unfocus();
      });
    } catch (e) {
      debugPrint("DetailedSearchPage: Location fetch error: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur de localisation : $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : AppTheme.primaryBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.itineraries,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.primaryBlue,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildSearchCard(isDark),
              const SizedBox(height: 24),
              if (_isLoading) _buildShimmerLoading(isDark) else _buildResults(l10n),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildSearchCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.1),
        ),
      ),
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildInputRow(
                  controller: _departController,
                  focusNode: _departFocusNode,
                  hint: 'Lieu de départ',
                  icon: Icons.my_location,
                  onIconPressed: _setCurrentLocationAsDeparture,
                  isDepart: true,
                  isDark: isDark,
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 48),
                  child: Divider(height: 1),
                ),
                _buildInputRow(
                  controller: _arriveeController,
                  focusNode: _arriveeFocusNode,
                  hint: 'Destination',
                  icon: Icons.search,
                  onIconPressed: _searchRoutes,
                  isDepart: false,
                  isDark: isDark,
                ),
              ],
            ),
          ),
          Positioned(
            right: 48,
            child: _ScaleOnTap(
              onTap: _swapLocations,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkBg : Colors.grey.shade50,
                  shape: BoxShape.circle,
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                ),
                child: const Icon(Icons.swap_vert, size: 20, color: AppTheme.primaryBlue),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required VoidCallback onIconPressed,
    required bool isDepart,
    required bool isDark,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppTheme.spacingS),
                decoration: BoxDecoration(
                  color: isDepart ? Colors.green.withOpacity(0.08) : Colors.red.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isDepart ? Icons.radio_button_checked : Icons.location_on,
                  color: isDepart ? Colors.green : Colors.red,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppTheme.spacingM),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: (v) => _onInputChanged(v, isDepart),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.normal),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              _buildAnimatedIconButton(icon: icon, onPressed: onIconPressed, isDark: isDark),
            ],
          ),
        ),
        if (isDepart && _showDepartSuggestions && _departSuggestions.isNotEmpty)
          _buildSuggestionsList(isDepart: true, isDark: isDark),
        if (!isDepart && _showArriveeSuggestions && _arriveeSuggestions.isNotEmpty)
          _buildSuggestionsList(isDepart: false, isDark: isDark),
      ],
    );
  }

  Widget _buildAnimatedIconButton({required IconData icon, required VoidCallback onPressed, required bool isDark}) {
    return _ScaleOnTap(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, color: AppTheme.primaryBlue, size: 22),
      ),
    );
  }

  Widget _buildSuggestionsList({required bool isDepart, required bool isDark}) {
    final suggestions = isDepart ? _departSuggestions : _arriveeSuggestions;

    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkBg : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = suggestions[index];
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, size: 18),
            title: Text(suggestion['description'] ?? '', style: const TextStyle(fontSize: 14)),
            onTap: () => _onSuggestionSelected(suggestion, isDepart),
          );
        },
      ),
    );
  }

  Widget _buildResults(AppLocalizations l10n) {
    if (_directionsResult == null) return const SizedBox.shrink();

    final directions = dr.DirectionsResponse.fromJson(_directionsResult!);
    final busRoutes = directions.routes.where((route) {
      return route.legs.any((leg) => leg.steps.any((step) => 
        step.travelMode == 'TRANSIT' && 
        step.transitDetails?.line.vehicle.type == 'BUS'));
    }).toList();

    if (busRoutes.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.bus_alert_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(l10n.noRoutesFound, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.itineraries, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: busRoutes.length,
          itemBuilder: (context, index) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 300 + (index * 100)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(15 * (1 - value), 0),
                    child: child,
                  ),
                );
              },
              child: RouteSummaryCard(route: busRoutes[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildShimmerLoading(bool isDark) {
    return Column(
      children: List.generate(3, (index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      )),
    );
  }
}

class _ScaleOnTap extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ScaleOnTap({required this.child, required this.onTap});

  @override
  State<_ScaleOnTap> createState() => _ScaleOnTapState();
}

class _ScaleOnTapState extends State<_ScaleOnTap> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scale,
        child: widget.child,
      ),
    );
  }
}
