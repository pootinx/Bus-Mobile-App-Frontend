
import 'package:bus_app/features/bus_routes/presentation/pages/bus_lines_page.dart';
import 'package:bus_app/features/search/presentation/pages/search_page.dart';
import 'package:bus_app/features/stations/presentation/pages/stations_page.dart';
import 'package:bus_app/features/t_pass/presentation/pages/t_pass_page.dart';
import 'package:bus_app/features/auth/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SearchPage(), // Tab 1: Itinéraires (with From/To)
    const StationsPage(), // Tab 2: Stations
    const TPassPage(), // Tab 3: T-PASS
    const BusLinesPage(), // Tab 4: Lignes
    const ProfilePage(), // Tab 5: Profile
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        selectedItemColor: const Color(0xFF1E3A8A),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Itinéraires'),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Stations'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'T-PASS'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Lignes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
