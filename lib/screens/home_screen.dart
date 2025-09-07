import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'stations_screen.dart'; // Ajouté : page des stations

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController searchController = TextEditingController();
  int _currentIndex = 0;

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    if (index == 2) {
      Navigator.pushNamed(context, '/lines');
    }else if (index == 3) {
      Navigator.pushNamed(context, '/add_bus');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget currentPage;

    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Color(0xFF1E3A8A), // same as AppBar color
      statusBarIconBrightness: Brightness.light, // icons: white
      statusBarBrightness: Brightness.dark, // for iOS (optional)
    ));

    if (_currentIndex == 1) {
      // 🔵 Onglet Stations
      currentPage = const StationsScreen();
    } else {
      // 🟢 Onglet Itinéraires (page d'accueil)
      currentPage = Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A), // Bleu foncé
              Color(0xFF3B82F6), // Bleu moyen
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec icône et titre
              Container(
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
                      child: const Icon(
                        Icons.directions_bus,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),
                    // const Text(
                    //   'Planifiez votre voyage en bus',
                    //   style: TextStyle(
                    //     fontSize: 26,
                    //     fontWeight: FontWeight.bold,
                    //     color: Colors.white,
                    //   ),
                    //   textAlign: TextAlign.center,
                    // ),
                    // const SizedBox(height: 12),
                    Text(
                      'Trouvez facilement le meilleur itinéraire en bus pour vous déplacer dans la ville.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              // Contenu principal avec fond blanc
              Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Badges de fonctionnalités
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildFeatureBadge(
                            icon: Icons.schedule,
                            label: 'Temps réel',
                            color: Colors.green,
                          ),
                          // const SizedBox(width: 2),
                          _buildFeatureBadge(
                            icon: Icons.navigation,
                            label: 'Navigation',
                            color: Colors.blue,
                          ),
                          _buildFeatureBadge(
                            icon: Icons.location_on,
                            label: 'Précis',
                            color: Colors.orange,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Barre de recherche améliorée
                      const Text(
                        'Rechercher une destination',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 2,
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: searchController,
                          onSubmitted: (value) {
                            final query = value.trim();
                            if (query.isNotEmpty) {
                              Navigator.pushNamed(
                                context,
                                '/search',
                                arguments: query,
                              );
                            }
                          },
                          decoration: InputDecoration(
                            hintText: 'Où voulez-vous aller ?',
                            hintStyle: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 16,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Colors.grey.shade600,
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                final query = searchController.text.trim();
                                if (query.isNotEmpty) {
                                  Navigator.pushNamed(
                                    context,
                                    '/search',
                                    arguments: query,
                                  );
                                }
                              },
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Colors.orange, Colors.deepOrange],
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.arrow_forward,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Raccourcis rapides
                      const Text(
                        'Raccourcis rapides',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pushNamed(context, '/stations');
                              },
                              child: _buildQuickAction(
                                icon: Icons.my_location,
                                label: 'Proche de moi',
                                color: Colors.blue,
                              ),
                            ),
                          ),

                          // const SizedBox(width: 12),
                          // Expanded(
                          //   child: _buildQuickAction(
                          //     icon: Icons.favorite,
                          //     label: 'Favoris',
                          //     color: Colors.red,
                          //   ),
                          // ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Notification de localisation améliorée
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade50,
                              Colors.orange.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.location_on,
                                color: Colors.orange.shade700,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Activez la géolocalisation pour des informations précises sur votre trajet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(child: currentPage),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.white,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.route),
              label: 'Itinéraires',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.location_on),
              label: 'Stations',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.alt_route),
              label: 'Lignes',
            ),
            // BottomNavigationBarItem(icon: Icon(Icons.add), label: 'Ajouter',),
          ],
        ),
      
      ),
    );
  }

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}