import 'package:bus_app/features/bus_routes/presentation/pages/bus_lines_page.dart';
import 'package:bus_app/features/home/presentation/pages/home_page.dart';
import 'package:bus_app/features/t_pass/presentation/pages/t_pass_page.dart';
import 'package:bus_app/features/auth/presentation/pages/profile_page.dart';
import 'package:bus_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:bus_app/l10n/app_localizations.dart';

import 'package:animations/animations.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomePage(),
    const TPassPage(),
    const BusLinesPage(),
    const ProfilePage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: PageTransitionSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, primaryAnimation, secondaryAnimation) {
          return FadeThroughTransition(
            animation: primaryAnimation,
            secondaryAnimation: secondaryAnimation,
            child: child,
          );
        },
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabTapped,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.1),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.search_rounded),
            selectedIcon: const Icon(Icons.search_rounded, size: 28, color: AppTheme.primaryBlue),
            label: l10n.itineraries,
          ),
          NavigationDestination(
            icon: const Icon(Icons.credit_card_outlined),
            selectedIcon: const Icon(Icons.credit_card_rounded, size: 28, color: AppTheme.primaryBlue),
            label: l10n.tPass,
          ),
          NavigationDestination(
            icon: const Icon(Icons.directions_bus_outlined),
            selectedIcon: const Icon(Icons.directions_bus_rounded, size: 28, color: AppTheme.primaryBlue),
            label: l10n.lines,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline_rounded),
            selectedIcon: const Icon(Icons.person_rounded, size: 28, color: AppTheme.primaryBlue),
            label: l10n.profile,
          ),
        ],
      ),
    );
  }
}
