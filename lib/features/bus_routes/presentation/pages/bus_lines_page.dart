import 'package:bus_app/core/services/location_service.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import 'package:animations/animations.dart';

import 'package:bus_app/features/bus_routes/presentation/pages/bus_line_details_page.dart';

class BusLinesPage extends StatelessWidget {
  const BusLinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const CityListScreen();
  }
}

class CityListScreen extends StatefulWidget {
  const CityListScreen({super.key});

  @override
  State<CityListScreen> createState() => _CityListScreenState();
}

class _CityListScreenState extends State<CityListScreen> {
  List<String> allCities = [];
  bool _isLoading = true;
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadCities();
    await _detectAndNavigate();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCities() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('cities').get();
      if (mounted) {
        final cities = snapshot.docs
            .map((doc) => doc.data()['name']?.toString().toLowerCase().trim())
            .whereType<String>()
            .toList();
        setState(() => allCities = cities);
      }
    } catch (e) {
      debugPrint("Error loading cities: $e");
    }
  }

  Future<void> _detectAndNavigate() async {
    try {
      final latLng = await _locationService.getCurrentLocation();
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final cityName = placemarks.first.locality?.toLowerCase().trim();

        if (cityName != null && allCities.contains(cityName)) {
           Get.to(() => BusLinesListScreen(city: cityName));
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to detect city or navigate: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Villes Desservies", style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _isLoading ? _buildShimmer(isDark) : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (allCities.isEmpty) {
        return const Center(child: Text("Aucune ville trouvée."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allCities.length,
      itemBuilder: (context, index) {
        final city = allCities[index];
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          color: isDark ? AppTheme.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.withOpacity(0.1)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: const CircleAvatar(
              backgroundColor: AppTheme.primaryBlue,
              child: Icon(Icons.location_city, color: Colors.white, size: 20),
            ),
            title: Text(
              city[0].toUpperCase() + city.substring(1),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Get.to(() => BusLinesListScreen(city: city)),
          ),
        );
      },
    );
  }

  Widget _buildShimmer(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 80,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class BusLinesListScreen extends StatefulWidget {
  final String city;

  const BusLinesListScreen({super.key, required this.city});

  @override
  State<BusLinesListScreen> createState() => _BusLinesListScreenState();
}

class _BusLinesListScreenState extends State<BusLinesListScreen> {
  late Stream<QuerySnapshot> cityStream;

  @override
  void initState() {
    super.initState();
    cityStream = FirebaseFirestore.instance.collection(widget.city).snapshots();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Lignes de ${widget.city[0].toUpperCase() + widget.city.substring(1)}", style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: cityStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerDetails(isDark);
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Aucune ligne trouvée."));
          }

          final seenNames = <String>{};
          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = (data['route_name'] ?? doc.id).toString().trim();
            if (seenNames.contains(name)) return false;
            seenNames.add(name);
            return true;
          }).toList();

          docs.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;
            final routeNameA = (dataA['route_name'] ?? a.id).toString().trim();
            final routeNameB = (dataB['route_name'] ?? b.id).toString().trim();
            return _compareRouteNames(routeNameA, routeNameB);
          });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final routeName = data['route_name'] ?? doc.id;

              Color color;
              try {
                final hex = data['color'];
                color = hex != null ? _hexToColor(hex) : _defaultColors[index % _defaultColors.length];
              } catch (_) {
                color = _defaultColors[index % _defaultColors.length];
              }

              String start = 'Départ inconnu';
              String end = 'Arrivée inconnue';
              if (data['stops'] is List) {
                final stops = List<Map<String, dynamic>>.from(data['stops']);
                if (stops.isNotEmpty) {
                  start = stops.first['name'] ?? start;
                  end = stops.last['name'] ?? end;
                }
              }

              return OpenContainer(
                transitionDuration: const Duration(milliseconds: 500),
                openBuilder: (context, _) => BusLineDetailsPage(lineData: {...data, 'color_final': color}),
                closedElevation: 0,
                closedColor: Colors.transparent,
                closedBuilder: (context, openContainer) => _buildBusCard(
                  routeName: routeName.toString(),
                  color: color,
                  start: start,
                  end: end,
                  isDark: isDark,
                  onTap: openContainer,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBusCard({
    required String routeName,
    required Color color,
    required String start,
    required String end,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? AppTheme.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.directions_bus_rounded, color: color, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Ligne $routeName",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.trip_origin, size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(start, style: const TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, size: 12, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(end, style: const TextStyle(fontSize: 13, color: Colors.grey), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerDetails(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  int _compareRouteNames(String a, String b) {
    final regexA = RegExp(r'(\D*)(\d+)(.*)');
    final regexB = RegExp(r'(\D*)(\d+)(.*)');
    final matchA = regexA.firstMatch(a.toLowerCase());
    final matchB = regexB.firstMatch(b.toLowerCase());

    if (matchA != null && matchB != null) {
      final prefixA = matchA.group(1) ?? '';
      final prefixB = matchB.group(1) ?? '';
      if (prefixA != prefixB) return prefixA.compareTo(prefixB);
      final numA = int.tryParse(matchA.group(2) ?? '0') ?? 0;
      final numB = int.tryParse(matchB.group(2) ?? '0') ?? 0;
      if (numA != numB) return numA.compareTo(numB);
      final suffixA = matchA.group(3) ?? '';
      final suffixB = matchB.group(3) ?? '';
      return suffixA.compareTo(suffixB);
    }
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse(hex, radix: 16));
  }

  static const List<Color> _defaultColors = [
    Colors.blue, Colors.green, Colors.red, Colors.orange,
    Colors.purple, Colors.teal, Colors.indigo,
  ];
}
