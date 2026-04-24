import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/notification_service.dart';
import 'phone_auth_screen.dart';

class AppSettingsScreen extends StatefulWidget {
  const AppSettingsScreen({super.key});

  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}

class _AppSettingsScreenState extends State<AppSettingsScreen> {
  bool _notificationsEnabled = true;
  bool _isSyncing = false;
  final User? _user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);
    
    if (!value) {
      // Logic to cancel all notifications if disabled globally
      // In a real app, you might want to stop scheduling new ones.
    }
  }

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);
    await SyncService().syncUnsyncedRecords();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Cloud synchronization complete')),
      );
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: const Color(0xFF1A2151),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 32),
          _buildSectionTitle('General'),
          _buildSettingTile(
            icon: LucideIcons.bell,
            title: 'Push Notifications',
            subtitle: 'Alerts for upcoming flights',
            trailing: Switch.adaptive(
              value: _notificationsEnabled,
              activeColor: const Color(0xFFF27121),
              onChanged: _toggleNotifications,
            ),
          ),
          _buildSettingTile(
            icon: LucideIcons.testTube,
            title: 'Send Test Notification',
            subtitle: 'Verify notification delivery',
            onTap: () async {
              await NotificationService().triggerTestNotification();
            },
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Data & Sync'),
          _buildSettingTile(
            icon: LucideIcons.refreshCw,
            title: 'Force Cloud Sync',
            subtitle: _isSyncing ? 'Syncing...' : 'Upload unsynced changes',
            trailing: _isSyncing 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.chevron_right, size: 20),
            onTap: _isSyncing ? null : _triggerManualSync,
          ),
          const SizedBox(height: 32),
          _buildSectionTitle('Account'),
          _buildSettingTile(
            icon: LucideIcons.logOut,
            title: 'Logout',
            subtitle: 'Sign out of SafariPass',
            titleColor: Colors.redAccent,
            onTap: () => _handleLogout(context),
          ),
          const SizedBox(height: 40),
          Center(
            child: Text(
              'SafariPass v0.1.0-alpha',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: const Color(0xFF1A2151),
            child: Text(
              (_user?.displayName != null && _user!.displayName!.isNotEmpty)
                  ? _user!.displayName!.substring(0, 1).toUpperCase()
                  : 'U',
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _user?.displayName ?? 'Valued Traveler',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A2151)),
                ),
                Text(
                  _user?.phoneNumber ?? 'No phone linked',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    Color? titleColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white), // For slight lift
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 20, color: titleColor ?? const Color(0xFF1A2151)),
        ),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: titleColor)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
        trailing: trailing,
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService().signOut();
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PhoneAuthScreen()),
          (route) => false,
        );
      }
    }
  }
}
