
import 'package:bus_app/screens/bus_lines_screen.dart';
import 'package:bus_app/screens/search_firebase/search.dart';
import 'package:bus_app/screens/t_pass/t_pass_screen.dart';
import 'package:bus_app/features/authentication/screens/profile_screen/profile_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const SearchRouteScreen(),
    const TPassScreen(),
    const BusLinesScreen(),
    const ProfileScreen(),
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
        selectedItemColor: const Color(0xFF005C97),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // This will fix the issue
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.route), label: 'Itinéraires'),
          BottomNavigationBarItem(icon: Icon(Icons.credit_card), label: 'T-PASS'),
          BottomNavigationBarItem(icon: Icon(Icons.alt_route), label: 'Lignes'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
