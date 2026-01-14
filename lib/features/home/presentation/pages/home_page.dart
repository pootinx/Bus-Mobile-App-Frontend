import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:bus_app/features/home/presentation/widgets/feature_badge.dart';
import 'package:bus_app/features/home/presentation/widgets/quick_action_card.dart';
import 'package:bus_app/features/home/presentation/widgets/home_search_bar.dart';
import 'package:bus_app/features/search/presentation/pages/search_page.dart';
import 'package:bus_app/core/widgets/location_disclaimer.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void _navigateToSearch(String query) {
    if (query.trim().isNotEmpty) {
      Get.to(() => SearchPage(initialQuery: query));
    }
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1E3A8A),
      statusBarIconBrightness: Brightness.light,
    ));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            _buildMainContent(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.directions_bus, size: 40, color: Colors.white),
          ),
          const SizedBox(height: 16),
          const Text(
            'Trouvez facilement le meilleur itinéraire en bus pour vous déplacer.',
            style: TextStyle(fontSize: 16, color: Colors.white),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FeatureBadge(icon: Icons.schedule, label: 'Temps réel', color: Colors.green),
              FeatureBadge(icon: Icons.navigation, label: 'Navigation', color: Colors.blue),
              FeatureBadge(icon: Icons.location_on, label: 'Précis', color: Colors.orange),
            ],
          ),
          const SizedBox(height: 40),
          const Text(
            'Rechercher une destination',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          HomeSearchBar(
            controller: searchController,
            onSubmitted: _navigateToSearch,
          ),
          const SizedBox(height: 32),
          const Text('Raccourcis rapides', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: QuickActionCard(
                  icon: Icons.my_location,
                  label: 'Proche de moi',
                  color: Colors.blue,
                  onTap: () => Navigator.pushNamed(context, '/stations'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const LocationDisclaimer(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}