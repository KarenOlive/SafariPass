import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:collection/collection.dart'; 
import '../services/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/sms_consent_service.dart';          
import '../widgets/sms_prompt_button.dart';
import '../widgets/current_journey_card.dart';
import '../widgets/journey_selector_bottom_sheet.dart';
import '../widgets/sms_consent_modal.dart';
import '../widgets/journey_card.dart'; 

class TripsTimelineScreen extends StatefulWidget {
  const TripsTimelineScreen({super.key});

  @override
  State<TripsTimelineScreen> createState() => _TripsTimelineScreenState();
}

class _TripsTimelineScreenState extends State<TripsTimelineScreen> {
  // SMS detection variables
  bool _hasPendingSMS = false;
  bool _isImporting = false;
  String? _pendingSmsContent;
  String? _pendingSmsFrom;
  late SharedPreferences _prefs;
  static const String _lastSmsTimestampKey = 'last_processed_sms_timestamp';
  final SmsConsentService _smsConsentService = SmsConsentService();

  // Journeys state
  List<Map<String, dynamic>> _journeys = [];
  bool _isLoadingJourneys = true;
  Map<String, dynamic>? _currentJourney;


  @override
  void initState() {
    super.initState();
    _initPrefsAndSetupListener();
    _loadJourneys();
  }

  Future<void> _loadJourneys() async {
    setState(() => _isLoadingJourneys = true);
    final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();
    final journeys = await DatabaseHelper.instance.getAllJourneysWithStatus(userId);
    setState(() {
      _journeys = journeys;
      _isLoadingJourneys = false;
      // Determine current journey (first ongoing one)
      _currentJourney = journeys.firstWhereOrNull(
        (j) => j['derived_status'] == 'ongoing',
      );
    });
  }

  Future<void> _initPrefsAndSetupListener() async {
    _prefs = await SharedPreferences.getInstance();
    await _requestPermissionAndListen();
  }

  Future<void> _requestPermissionAndListen() async {
    final status = await Permission.sms.request();
    if (!status.isGranted) return;

    try {
      // Wait for an SMS (timeout after 60 seconds)
      final sms = await _smsConsentService.requestSms().timeout(
        const Duration(seconds: 60),
        onTimeout: () => null,
      );
      if (sms != null) {
        _processIncomingSms(sms);
      } else {
        // Timeout – restart listener
        _requestPermissionAndListen();
      }
    } catch (e) {
      // Error – maybe restart after a delay
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _requestPermissionAndListen();
      });
    }
  }

  void _processIncomingSms(String sms) {
    const keywords = ['SGR', 'Jambojet', 'Safarilink', 'PNR', 'Flight', 'MADARAKA', 'TICKET'];
    final upper = sms.toUpperCase();
    if (keywords.any((kw) => upper.contains(kw))) {
      setState(() {
        _hasPendingSMS = true;
        _pendingSmsContent = sms;
        _pendingSmsFrom = 'Unknown';
      });
    } else {
      // Not a travel SMS, keep listening
      _requestPermissionAndListen();
    }
  }

  Future<void> _handleSmsImport() async {
    if (_pendingSmsContent == null) {
      _showMessage('No pending SMS. Try receiving a new travel SMS.');
      return;
    }

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      _showMessage('No internet connection. Please try again later.');
      return;
    }

    setState(() => _isImporting = true);

    final allow = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SMSConsentModal(
        from: _pendingSmsFrom!,
        message: _pendingSmsContent!,
        onAllow: () => Navigator.pop(context, true),
        onDeny: () => Navigator.pop(context, false),
      ),
    );

    if (allow == true) {
      await _processSmsAndSave();
    } else {
      setState(() => _isImporting = false);
    }
  }

  Future<void> _processSmsAndSave() async {
    final ticketData = await GeminiService.parseSmsText(_pendingSmsContent!);
    if (ticketData == null) {
      _showMessage('Could not parse SMS. Please try manually.');
      setState(() => _isImporting = false);
      return;
    }

    final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();

    final selectedJourneyId = await showJourneySelector(context, userId);
    if (selectedJourneyId == null || selectedJourneyId.isEmpty) {
      _showMessage('Ticket not saved. No journey selected.');
      setState(() => _isImporting = false);
      return;
    }

    final ticketMap = ticketData.toMap();
    ticketMap['journey_id'] = selectedJourneyId;
    ticketMap['source_type'] = 'sms';
    ticketMap['raw_data'] = _pendingSmsContent;
    ticketMap['isSynced'] = 0;
    ticketMap['last_modified'] = DateTime.now().toIso8601String();

    await DatabaseHelper.instance.createTicketFromMap(ticketMap);

    await _prefs.setInt(_lastSmsTimestampKey, DateTime.now().millisecondsSinceEpoch);

    setState(() {
      _hasPendingSMS = false;
      _isImporting = false;
      _pendingSmsContent = null;
    });

    _showMessage('✅ Ticket imported successfully!');

       // Refresh journeys list (in case a new journey was created)
    _loadJourneys();
          // Restart listener for the next SMS
    _requestPermissionAndListen();
  }

  Future<List<Map<String, dynamic>>> _fetchTickets() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('ticket', orderBy: 'departure DESC');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: message.contains('✅') ? Colors.green : null),
    );
  }

  @override
  void dispose() {
    // No explicit cleanup needed for the service; it cleans up itself.
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              color: const Color(0xFF1A237E),
              padding: const EdgeInsets.only(top: 60, bottom: 32, left: 24, right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Your Journeys', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white)),
                  SizedBox(height: 8),
                  Text('Track all your travel in one place', style: TextStyle(fontSize: 16, color: Colors.white70)),
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
                  // Current Journey Card (only if ongoing)
                  if (_currentJourney != null) ...[
                    CurrentJourneyCard(journeyId: _currentJourney!['journey_id']),
                    const SizedBox(height: 24),
                  ],
                  // SMS prompt
                  if (_hasPendingSMS && !_isImporting)
                    SmsPromptButton(onImport: _handleSmsImport),
                  if (_isImporting)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  const SizedBox(height: 32),
                  const Text('All Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Journeys list
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

    // Group by derived_status
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

    // Sort each group by start_date (most recent first)
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
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
          ),
        ),
      );
      for (var journey in journeys) {
        widgets.add(
          JourneyCard(
            journey: journey,
            onTap: () {
              // TODO: navigate to journey details screen (could show tickets)
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