import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/sync_service.dart';
import '../widgets/current_journey_card.dart';
import '../widgets/journey_selector_bottom_sheet.dart';
import '../widgets/journey_card.dart';
import 'journey_detail_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/notification_service.dart';

class TripsTimelineScreen extends StatefulWidget {
  const TripsTimelineScreen({super.key});

  @override
  State<TripsTimelineScreen> createState() => _TripsTimelineScreenState();
}

class _TripsTimelineScreenState extends State<TripsTimelineScreen> with WidgetsBindingObserver {
  late SharedPreferences _prefs;
  final functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  // Journeys state
  List<Map<String, dynamic>> _journeys = [];
  bool _isLoadingJourneys = true;
  Map<String, dynamic>? _currentJourney;

  bool _hasRunAuthDebug = false;
  AppLifecycleState? _lastLifecycleState;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waitForAuthThenTest();
    _initPrefs();
    _loadJourneys();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _lastLifecycleState != AppLifecycleState.resumed) {
      debugPrint('📱 App resumed - refreshing journeys');
      _loadJourneys();
    }
    _lastLifecycleState = state;
  }

  Future<void> _waitForAuthThenTest() async {
    debugPrint("⏳ Waiting for Firebase Auth...");

    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user != null && !_hasRunAuthDebug) {
        _hasRunAuthDebug = true;
        debugPrint("✅ User detected: ${user.uid}");

        await Future.delayed(const Duration(seconds: 2));

        await _debugAuthAndFirestore(user);
        await SyncService().syncUnsyncedRecords();
        await _loadJourneys();
      } else {
        debugPrint("❌ No user signed in");
      }
    });
  }

  Future<void> _debugAuthAndFirestore(User user) async {
    try {
      print("🚀 Preparing to call Cloud Function syncUser...");

      final token = await user.getIdToken(true);

      if (token != null && token.length >= 20) {
        debugPrint("🔑 ID Token (shortened): ${token.substring(0, 20)}...");
      } else {
        debugPrint("⚠️ Token is null or too short: $token");
      }

      final localUser = await DatabaseHelper.instance.getCurrentFirebaseUser();
      final callable = functions.httpsCallable(
        'syncUser',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 30),
        ),
      );

      final result = await callable.call({
        'user_id': user.uid,
        'name': localUser?['name'] ?? user.displayName ?? '',
        'phone_hash': localUser?['phone_hash'] ?? user.phoneNumber ?? '',
        'last_modified': DateTime.now().toIso8601String(),
      });

      debugPrint("✅ Firestore write SUCCESS: ${result.data}");
    } catch (e) {
      print("❌ Firestore write FAILED: $e");
    }
  }

  Future<void> _initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> _loadJourneys() async {
    setState(() => _isLoadingJourneys = true);
    try {
      final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();
      final journeys = await DatabaseHelper.instance.getAllJourneysWithStatus(userId);
      setState(() {
        _journeys = journeys;
        _isLoadingJourneys = false;
        _currentJourney = journeys.firstWhereOrNull(
          (j) => j['derived_status'] == 'ongoing',
        );
      });
    } catch (e) {
      debugPrint("❌ Error loading journeys: $e");
      setState(() => _isLoadingJourneys = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: message.contains('✅') ? Colors.green : null),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        color: const Color(0xFFF27121),
        backgroundColor: Colors.white,
        onRefresh: () async {
          await SyncService().syncUnsyncedRecords();
          await _loadJourneys();
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                color: const Color(0xFF1A2151),
                padding: const EdgeInsets.only(top: 60, bottom: 32, left: 24, right: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Your Journeys', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                        IconButton(
                          icon: const Icon(Icons.notifications_active_outlined, color: Colors.white),
                          onPressed: () async {
                            await NotificationService().triggerTestNotification();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Test alert triggered! Check your notifications.')),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('Track all your travel in one place', style: TextStyle(fontSize: 16, color: Colors.white70)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_currentJourney != null)
                      CurrentJourneyCard(
                        key: ValueKey(_currentJourney!['journey_id']),
                        journeyId: _currentJourney!['journey_id'],
                      ),
                    if (_currentJourney != null) const SizedBox(height: 24),
                    const SizedBox(height: 32),
                    const Text('All Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2151))),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _isLoadingJourneys
                  ? const Center(child: CircularProgressIndicator())
                  : Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        children: _buildGroupedJourneys(),
                      ),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedJourneys() {
    if (_journeys.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Text(
              'No journeys yet.\nTap the Scan button to create one!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ),
        ),
      ];
    }

    final Map<String, List<Map<String, dynamic>>> grouped = {
      'ongoing': [],
      'upcoming': [],
      'completed': [],
    };

    for (var journey in _journeys) {
      final status = journey['derived_status'] as String;
      if (grouped.containsKey(status)) {
        grouped[status]!.add(journey);
      } else {
        grouped['upcoming']!.add(journey);
      }
    }

    for (var key in grouped.keys) {
      grouped[key]!.sort((a, b) => b['start_date'].compareTo(a['start_date']));
    }

    final List<Widget> widgets = [];

    void addSection(String title, List<Map<String, dynamic>> journeys) {
      if (journeys.isEmpty) return;
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2151)),
          ),
        ),
      );
      for (var journey in journeys) {
        widgets.add(
          JourneyCard(
            journey: journey,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JourneyDetailScreen(journeyId: journey['journey_id']),
                ),
              );
            },
          ),
        );
      }
    }

    addSection('In Progress', grouped['ongoing']!);
    addSection('Upcoming', grouped['upcoming']!);
    addSection('Completed', grouped['completed']!);

    return widgets;
  }
}
