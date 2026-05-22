import 'dart:async';
import 'package:bus_app/core/services/google_places_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:bus_app/core/utils/permission_handler.dart';
import 'package:bus_app/features/search/presentation/pages/detailed_search_page.dart';
import 'package:bus_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/surveys/services/survey_service.dart';
import 'package:bus_app/features/surveys/presentation/pages/survey_page.dart';
import 'package:bus_app/features/notifications/presentation/widgets/bell_icon.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isLocationPermissionGranted = false;
  final TextEditingController _searchController = TextEditingController();
  final GooglePlacesService _placesService = GooglePlacesService();
  List<Map<String, String>> _suggestions = [];
  Timer? _debounce;
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _checkLocationStatusSilent();
  }

  Future<void> _checkLocationStatusSilent() async {
    final granted = await PermissionHandler.checkLocationStatus();
    if (mounted) {
      setState(() {
        _isLocationPermissionGranted = granted;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onInputChanged(String input) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (input.length > 2) {
        try {
          final suggestions = await _placesService.getAutocomplete(input);
          if (!mounted) return;
          setState(() {
            _suggestions = suggestions;
            _showSuggestions = true;
          });
        } catch (e) {
          debugPrint("Autocomplete error: $e");
        }
      } else {
        if (!mounted) return;
        setState(() {
          _suggestions = [];
          _showSuggestions = false;
        });
      }
    });
  }

  Future<void> _onSuggestionSelected(Map<String, String> suggestion) async {
    final placeId = suggestion['place_id']!;
    final placeText = suggestion['description']!;

    try {
      final details = await _placesService.getPlaceDetails(placeId);
      final location = details['location'];
      final lat = location['latitude'];
      final lng = location['longitude'];

      debugPrint("HomePage: Selected Place: $placeText, LatLng: $lat, $lng");

      if (!mounted) return;
      setState(() {
        _suggestions = [];
        _showSuggestions = false;
        _searchController.clear();
      });

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetailedSearchPage(
            initialDestinationLatLng: LatLng(lat, lng),
            initialDestinationName: placeText,
          ),
        ),
      );
    } catch (e) {
      debugPrint("HomePage: Place details error: $e");
    }
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBg : AppTheme.lightBg,
      body: SafeArea(
        top: false,
        child: Stack(
          children: [
            // Background Layer: Header and main content scrolling area
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(l10n),
                ),
                SliverPadding(
                  padding: const EdgeInsets.only(
                    top: 80, // Space for the floating card
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      if (_showSuggestions && _suggestions.isNotEmpty)
                        _buildSuggestionsList(isDark),
                      const SizedBox(height: 10),
                      Obx(() {
                        final survey = SurveyService.to.activeSurvey.value;
                        if (survey != null && survey.isMandatory) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Material(
                              elevation: 2,
                              borderRadius: BorderRadius.circular(12),
                              color: const Color(0xFFFFF3CD),
                              child: ListTile(
                                leading: const Icon(Icons.assignment, color: Color(0xFF856404)),
                                title: const Text('Mandatory survey available', style: TextStyle(color: Color(0xFF856404), fontWeight: FontWeight.bold)),
                                trailing: const Icon(Icons.arrow_forward, color: Color(0xFF856404)),
                                onTap: () => Get.to(() => const SurveyPage()),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }),
                      _buildLocationBanner(context, isDark),
                      // Add other main page content here later
                    ]),
                  ),
                ),
              ],
            ),
            
            // Floating Layer: Search Card
            Positioned(
              top: 170, // Adjust this value to perfectly center the overlap horizontally with the header's curve
              left: 20,
              right: 20,
              child: _buildSearchField(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    const headerColor = Color(0xFF13AAFF);
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        color: headerColor,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(40),
          bottomRight: Radius.circular(40),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tobis',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const BellIcon(),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                "Trouver facilement le meilleur itinéraire en bus pour vous déplacer",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  height: 1.3,
                ),
                maxLines: 2,
              ),
            ],
          ),
    );
  }

  Widget _buildSearchField(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Rechercher une destination",
            style: TextStyle(
              color: Color(0xFF13AAFF),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 15),
          Center(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey.shade900 : const Color(0xFFE9F4FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  const Icon(Icons.search, color: Colors.grey, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onInputChanged,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetailedSearchPage(initialQuery: value),
                            ),
                          );
                        }
                      },
                      decoration: const InputDecoration(
                        hintText: "Où vas-tu ?",
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 15,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                        isDense: true,
                      ),
                      style: const TextStyle(
                        fontSize: 15,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      if (_searchController.text.isNotEmpty) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DetailedSearchPage(initialQuery: _searchController.text),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF13AAFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionsList(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusL),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final suggestion = _suggestions[index];
          return ListTile(
            leading: const Icon(Icons.location_on_outlined, size: 18),
            title: Text(
              suggestion['description'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
            onTap: () => _onSuggestionSelected(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildLocationBanner(BuildContext context, bool isDark) {
    const bannerColor = Color(0xFF2BA1FF); // Matches the vibrant cyan-blue in the image
    const shadowColor = Color(0x1A000000); // 10% black for subtle overlap shadows

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Container(
        width: double.infinity,
        height: 140, 
        color: bannerColor,
        child: Stack(
          children: [
            // Top right wide shape
            Positioned(
              top: -30,
              left: 40,
              right: -20,
              child: Container(
                height: 90,
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(45),
                  boxShadow: const [
                    BoxShadow(color: shadowColor, blurRadius: 15, offset: Offset(0, 6)),
                  ],
                ),
              ),
            ),
            // Middle left shape covering the left edge
            Positioned(
              top: -20,
              bottom: 20,
              left: -40,
              child: Container(
                width: 120,
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: const [
                    BoxShadow(color: shadowColor, blurRadius: 15, offset: Offset(6, 0)),
                  ],
                ),
              ),
            ),
            // Bottom left overlapping shape
            Positioned(
              bottom: -40,
              left: -10,
              child: Container(
                width: 180,
                height: 100,
                decoration: BoxDecoration(
                  color: bannerColor,
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: const [
                    BoxShadow(color: shadowColor, blurRadius: 15, offset: Offset(6, -4)),
                  ],
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "activez la localisation pour\ndes information preciser sur\nvotre trajet",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: GestureDetector(
                      onTap: () async {
                        if (_isLocationPermissionGranted) {
                          setState(() {
                            _isLocationPermissionGranted = false;
                          });
                        } else {
                          await _checkLocationPermission();
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 50,
                        height: 28,
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: _isLocationPermissionGranted
                              ? const Color(0xFF4BD964) // iOS Green style
                              : Colors.white.withOpacity(0.3), // Inactive/Off style
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOutCubic,
                          alignment: _isLocationPermissionGranted
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}