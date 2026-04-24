// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import 'journey_suggestions_screen.dart';
import 'phone_auth_screen.dart';
import 'travel_stats_screen.dart';
import 'app_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profile & Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildMenuTile(
            context,
            icon: Icons.auto_awesome, 
            title: 'AI Journey Planner',
            subtitle: 'Get smart route suggestions',
            color: Colors.purple,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const JourneySuggestionsScreen())),
          ),
          _buildMenuTile(
            context,
            icon: Icons.bar_chart,
            title: 'Travel Stats',
            subtitle: 'View your distance and savings',
            color: Colors.blue,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TravelStatsScreen())),
          ),
          _buildMenuTile(
            context,
            icon: Icons.settings,
            title: 'App Settings',
            subtitle: 'Privacy, Notifications, Theme',
            color: Colors.grey,
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AppSettingsScreen())),
          ),
          _buildMenuTile(
            context,
            icon: Icons.logout,
            title: 'Logout',
            subtitle: 'Sign out of your account',
            color: Colors.red,
            onTap: () async {
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, {required IconData icon, required String title, required String subtitle, required Color color, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withAlpha(30), shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}