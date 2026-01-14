
import 'package:bus_app/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';

import 'package:bus_app/features/bus_routes/presentation/pages/bus_line_details_page.dart';

class BusLinesPage extends StatefulWidget {
  const BusLinesPage({super.key});

  @override
  State<BusLinesPage> createState() => _BusLinesPageState();
}

class _BusLinesPageState extends State<BusLinesPage> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: _navigatorKey,
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const CityListScreen(),
        );
      },
    );
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
    final snapshot = await FirebaseFirestore.instance.collection('cities').get();
    if (mounted) {
      final cities = snapshot.docs
          .map((doc) => doc.data()['name']?.toString().toLowerCase().trim())
          .whereType<String>()
          .toList();
      setState(() => allCities = cities);
    }
  }

  Future<void> _detectAndNavigate() async {
    try {
      final latLng = await _locationService.getCurrentLocation();
      final placemarks = await placemarkFromCoordinates(latLng.latitude, latLng.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final cityName = placemarks.first.locality?.toLowerCase().trim();

        if (cityName != null && allCities.contains(cityName)) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BusLinesListScreen(city: cityName),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("❌ Failed to detect city or navigate: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        title: const Text("Lignes de bus", style: TextStyle(color: Colors.white)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : allCities.isEmpty
              ? const Center(child: Text("No cities found."))
              : ListView.builder(
                  itemCount: allCities.length,
                  itemBuilder: (context, index) {
                    final city = allCities[index];
                    return ListTile(
                      title: Text(city[0].toUpperCase() + city.substring(1)),
                      trailing: const Icon(Icons.location_city),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BusLinesListScreen(city: city),
                          ),
                        );
                      },
                    );
                  },
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
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF1E3A8A),
          iconTheme: const IconThemeData(color: Colors.white),
          title: Text("Lignes de ${widget.city}", style: const TextStyle(color: Colors.white)),
        ),
        body: StreamBuilder<QuerySnapshot>(
          stream: cityStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
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
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final doc = docs[index];
                final data = doc.data() as Map<String, dynamic>;
                final routeName = data['route_name'] ?? doc.id;

                Color color;
                try {
                  final hex = data['color'];
                  color = hex != null
                      ? _hexToColor(hex)
                      : _defaultColors[index % _defaultColors.length];
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

                return _buildEnhancedCard(
                  context: context,
                  routeName: routeName,
                  color: color,
                  start: start,
                  end: end,
                  data: data,
                );
              },
            );
          },
        ));
  }

  Widget _buildEnhancedCard({
    required BuildContext context,
    required String routeName,
    required Color color,
    required String start,
    required String end,
    required Map<String, dynamic> data,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey.shade50],
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
             Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BusLineDetailsPage(lineData: {...data, 'color_final': color}),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Hero(
                  tag: 'bus_icon_$routeName',
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [color, color.withOpacity(0.8)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: const Icon(Icons.directions_bus_rounded, color: Colors.white, size: 28),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: color.withOpacity(0.3)),
                        ),
                        child: Text("Ligne $routeName",
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color.withOpacity(0.9)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.radio_button_checked, size: 12, color: color.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(start, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ]),
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        height: 20,
                        width: 1,
                        child: CustomPaint(painter: DottedLinePainter(color: color.withOpacity(0.4))),
                      ),
                      Row(children: [
                        Icon(Icons.location_on, size: 12, color: color.withOpacity(0.7)),
                        const SizedBox(width: 6),
                        Expanded(child: Text(end, style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade600),
                ),
              ],
            ),
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
    Colors.red, Colors.green, Colors.blue, Colors.orange,
    Colors.purple, Colors.teal, Colors.amber, Colors.pink,
    Colors.cyan, Colors.deepOrange,
  ];
}

class DottedLinePainter extends CustomPainter {
  final Color color;
  DottedLinePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    const dashHeight = 2;
    const dashSpace = 2;
    double startY = 0;
    while (startY < size.height) {
      canvas.drawLine(Offset(0, startY), Offset(0, startY + dashHeight), paint);
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
