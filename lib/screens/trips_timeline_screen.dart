import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';
import '../services/sms_consent_service.dart';          
import '../widgets/ticket_card.dart';
import '../widgets/sms_prompt_button.dart';
import '../widgets/current_journey_card.dart';
import '../widgets/journey_selector_bottom_sheet.dart';
import '../widgets/sms_consent_modal.dart';
import 'ticket_detail_screen.dart';

class TripsTimelineScreen extends StatefulWidget {
  const TripsTimelineScreen({super.key});

  @override
  State<TripsTimelineScreen> createState() => _TripsTimelineScreenState();
}

class _TripsTimelineScreenState extends State<TripsTimelineScreen> {
  bool _hasPendingSMS = false;
  bool _isImporting = false;
  String? _pendingSmsContent;
  String? _pendingSmsFrom;
  late SharedPreferences _prefs;
  static const String _lastSmsTimestampKey = 'last_processed_sms_timestamp';
  final SmsConsentService _smsConsentService = SmsConsentService();  // ← NEW

  @override
  void initState() {
    super.initState();
    _initPrefsAndSetupListener();
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
                  const CurrentJourneyCard(),
                  const SizedBox(height: 24),
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
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchTickets(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No trips found.\nTap the Scan button to add one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ),
                  ),
                );
              }

              final tickets = snapshot.data!;
              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: TicketCard(
                        ticket: tickets[index],
                        onClick: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => TicketDetailScreen(ticket: tickets[index])),
                        ),
                      ),
                    );
                  },
                  childCount: tickets.length,
                ),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}