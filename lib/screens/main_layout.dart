import 'package:flutter/material.dart';
import '../widgets/custom_bottom_nav.dart';
import 'scanner_screen.dart';
import 'trips_timeline_screen.dart';
import 'profile_screen.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0; // Starts on 'Trips'

  final List<Widget> _screens = [
    const TripsTimelineScreen(), // Index 0
    const ScannerScreen(), // Index 1 – no journeyId passed; user selects journey after scan                     // Index 1
    const ProfileScreen(), // Index 2
  ];

  @override
 Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack( // Using IndexedStack preserves screen state
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: CustomBottomNav(
        currentIndex: _currentIndex,
        onTabChanged: (index) {
          setState(() => _currentIndex = index);
        },
      ),
    );
  }
}