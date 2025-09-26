import 'package:bus_app/models/route_frbase.dart';
import 'package:bus_app/models/route_map_firestore.dart';
import 'package:bus_app/screens/search_firebase/frbase.dart';
import 'package:bus_app/widgets/route_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;

class SearchRouteScreenV1 extends StatefulWidget {
  const SearchRouteScreenV1({super.key});

  @override
  State<SearchRouteScreenV1> createState() => _SearchRouteScreenV1State();
}

class _SearchRouteScreenV1State extends State<SearchRouteScreenV1> {
  final TextEditingController departController = TextEditingController();
  final TextEditingController arriveeController = TextEditingController();
  final FirestoreRouteServiceV2 firestoreService = FirestoreRouteServiceV2();

  List<FirestoreRouteResultV1>? firestoreResults;
  bool isLoading = false;
  int _currentIndex = 0;
  bool _hasInitialized = false; // Add flag to prevent multiple calls

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is String && args.isNotEmpty) {
      arriveeController.text = args;
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize search only once when widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasInitialized) {
        _hasInitialized = true;
        _initializeSearch();
      }
    });
  }

  // Separate initialization method
  Future<void> _initializeSearch() async {
    if (arriveeController.text.isNotEmpty) {
      await searchRoutes();
    }
  }

  Future<void> searchRoutes() async {
    final arrivee = arriveeController.text.trim();

    if (arrivee.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Merci de renseigner une destination')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        isLoading = true;
        firestoreResults = null;
      });
    }

    try {
      // 1. Get user location and resolve city + readable location name
      final position = await firestoreService.getUserLocation();
      final detectedCity = await firestoreService.getCityNameFromCoordinates(
        position.latitude,
        position.longitude,
      );
      var departLocationName = await firestoreService.getLocationNameFromCoordinates(
        position.latitude,
        position.longitude,
      );

      print("---------object $departLocationName");

      // 2. Match detected city to Firestore cities
      final firestoreCities = await firestoreService.getCitiesFromFirestore();
      final matchedCity = firestoreService.matchCity(detectedCity, firestoreCities) ?? "tetouane";

      // 3. Get coordinates from names
      var startCoords = LatLng(position.latitude, position.longitude); // Use actual GPS
      final endCoords = await getCoordinatesFromPlaceName('$arrivee, $matchedCity');

      if (endCoords == null) {
        throw Exception("Impossible de localiser la destination : $arrivee");
      }

      // test (remove this in production)
      departLocationName = "Aéroport, $matchedCity";
      startCoords = LatLng(35.591311025851894, -5.33091575508334);

      // 4. Search routes
      final results = await firestoreService.searchCityRoutesByCoords(
        cityName: matchedCity,
        startCoords: startCoords,
        endCoords: endCoords,
        startAddress: departLocationName,
        endAddress: arrivee,
      );

      if (mounted) {
        setState(() {
          firestoreResults = results;
          isLoading = false;
        });

        if (results.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Aucun itinéraire trouvé depuis votre position")),
          );
        }
      }

      print("✅ Trajet trouvé depuis: $departLocationName → $arrivee ($matchedCity)");
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erreur lors de la recherche : $e")),
        );
      }
    }
  }

  Future<LatLng?> getCoordinatesFromPlaceName(String placeName) async {
    try {
      List<Location> locations = await locationFromAddress(placeName);

      if (locations.isNotEmpty) {
        final loc = locations.first;
        return LatLng(loc.latitude, loc.longitude);
      }
    } catch (e) {
      print('❌ Error getting coordinates for "$placeName": $e');
    }

    return null; // Not found or error
  }

  Future<void> getPlaceNameFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String name = [
          place.name,
          place.street,
          place.locality,
          place.administrativeArea,
          place.country
        ].where((s) => s != null && s.trim().isNotEmpty).join(", ");

        print("📍 Place name: $name");
      } else {
        print("⚠️ No placemark found");
      }
    } catch (e) {
      print("❌ Error in reverse geocoding: $e");
    }
  }

  Future<void> setCurrentLocationAsDeparture() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever || permission == LocationPermission.denied) {
        throw Exception("Permission refusée");
      }

      Position position = await Geolocator.getCurrentPosition();
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          departController.text = "${place.street}, ${place.locality}";
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur localisation: $e')),
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

  String _calculerDureeParcourue(String startTime, String endTime) {
    try {
      final format = RegExp(r'^(\d{2}):(\d{2}):(\d{2})$');
      if (format.hasMatch(startTime) && format.hasMatch(endTime)) {
        final startParts = startTime.split(':').map(int.parse).toList();
        final endParts = endTime.split(':').map(int.parse).toList();

        final start = DateTime(2023, 1, 1, startParts[0], startParts[1], startParts[2]);
        final end = DateTime(2023, 1, 1, endParts[0], endParts[1], endParts[2]);

        Duration diff = end.difference(start);
        if (diff.isNegative) {
          diff += const Duration(hours: 24);
        }

        final heures = diff.inHours;
        final minutes = diff.inMinutes % 60;

        return heures > 0 ? "$heures heure${heures > 1 ? 's' : ''} $minutes min" : "$minutes min";
      }
    } catch (_) {}
    return "Durée inconnue";
  }

  String _getFirstStopName(List<Map<String, dynamic>> stops) =>
      stops.isNotEmpty ? stops.first['name'] ?? 'Arrêt inconnu' : 'Arrêt inconnu';

  String _getLastStopName(List<Map<String, dynamic>> stops) =>
      stops.isNotEmpty ? stops.last['name'] ?? 'Arrêt inconnu' : 'Arrêt inconnu';

  @override
  Widget build(BuildContext context) {
    // REMOVED: searchRoutes() call from here - this was causing infinite rebuilds
    return Scaffold(
      appBar: AppBar(title: const Text("Rechercher un itinéraire")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildSearchBar(),
            const SizedBox(height: 16),
            if (isLoading)
              const Center(child: CircularProgressIndicator()),
            if (!isLoading && firestoreResults != null)
              Expanded(child: _buildFirestoreResults()),
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
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        children: [
          // Uncomment if you want to show departure field
          // Row(
          //   children: [
          //     const Padding(
          //       padding: EdgeInsets.symmetric(horizontal: 8),
          //       child: Icon(Icons.circle, color: Colors.green, size: 16),
          //     ),
          //     Expanded(
          //       child: TextField(
          //         controller: departController,
          //         decoration: const InputDecoration(
          //           hintText: "Lieu de départ",
          //           border: InputBorder.none,
          //         ),
          //       ),
          //     ),
          //     IconButton(
          //       icon: const Icon(Icons.my_location, color: Colors.orange),
          //       onPressed: setCurrentLocationAsDeparture,
          //     ),
          //   ],
          // ),
          // const Divider(height: 1),
          Row(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.flag, color: Colors.red, size: 16),
              ),
              Expanded(
                child: TextField(
                  controller: arriveeController,
                  decoration: const InputDecoration(
                    hintText: "Destination",
                    border: InputBorder.none,
                  ),
                  onSubmitted: (_) => searchRoutes(),
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

  Widget _buildFirestoreResults() {
    if (firestoreResults!.isEmpty) {
      return const Center(
        child: Text("Aucun itinéraire trouvé", style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: firestoreResults!.length,
      itemBuilder: (context, index) {
        final result = firestoreResults![index];
        return RouteSummaryCardV1(result: result);
      },
    );
  }

  Widget _buildFirestoreRouteCard(FirestoreRouteResultV1 result) {
    final duree = _calculerDureeParcourue(result.startTime, result.endTime);
    final distance = result.busDistance;
    final startTimeFormatted = result.startTime.substring(0, 5);
    final endTimeFormatted = result.endTime.substring(0, 5);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.directions_bus, color: Colors.blue),
                const SizedBox(width: 8),
                Text("$startTimeFormatted → $endTimeFormatted", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("$distance km", style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            Text(duree, style: const TextStyle(color: Colors.blue, fontSize: 16)),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.directions_walk, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(result.colorValue),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(result.lineName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
                const SizedBox(width: 8),
                const Icon(Icons.directions_walk, color: Colors.blue, size: 20),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _showRouteDetails(result),
              child: const Row(
                children: [
                  Icon(Icons.keyboard_arrow_up, color: Colors.blue),
                  Text("Voir les détails", style: TextStyle(color: Colors.blue)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRouteDetails(FirestoreRouteResultV1 result) {
    final firstStop = _getFirstStopName(result.stops);
    final lastStop = _getLastStopName(result.stops);

    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Détails du trajet - Ligne ${result.lineName}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDetailRow(Icons.directions_walk, "Marcher jusqu'à $firstStop"),
            _buildDetailRow(Icons.directions_bus, "Bus ligne ${result.lineName} vers .."),
            _buildDetailRow(Icons.directions_walk, "Marcher depuis $lastStop"),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => RouteMapScreen.fromFirestore(result)),
                  );
                },
                child: const Text("Voir sur la carte"),
              ),
            ),
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
          Icon(icon, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    departController.dispose();
    arriveeController.dispose();
    super.dispose();
  }
}