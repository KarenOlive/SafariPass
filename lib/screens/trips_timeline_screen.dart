import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'ticket_detail_screen.dart';
import '../widgets/ticket_card.dart';
import '../widgets/sms_consent_modal.dart';

class TripsTimelineScreen extends StatefulWidget {
  const TripsTimelineScreen({super.key});

  @override
  State<TripsTimelineScreen> createState() => _TripsTimelineScreenState();
}

class _TripsTimelineScreenState extends State<TripsTimelineScreen> {
  // 1. STATE VARIABLE FOR SMS VISIBILITY
  // Set to true for testing. In production, a background service 
  // would set this to true when it detects a new booking SMS.
  bool _hasPendingSMS = true; 

  Future<List<Map<String, dynamic>>> _fetchTickets() async {
    final db = await DatabaseHelper.instance.database;
    return await db.query('ticket', orderBy: 'departure DESC');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: CustomScrollView(
        slivers: [
          // Navy Header
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

          // Main Content Area
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCurrentJourneyCard(),
                  const SizedBox(height: 24),
                  
                  // 2. ONLY SHOW SMS PROMPT IF A TICKET IS DETECTED
                  if (_hasPendingSMS) ...[
                    _buildSMSPromptButton(),
                    const SizedBox(height: 32),
                  ],

                  const Text('All Trips', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // SQLite Data List
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
                      child: Text('No trips found.\nTap the Scan button to add one!', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], fontSize: 16)),
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

  // ---------------- UI COMPONENTS ---------------- //

  Widget _buildSMSPromptButton() {
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => SMSConsentModal(
            from: 'MADARAKA EXPRESS',
            message: 'Ticket Confirmed: NRB-MSA. PNR: 2K9J6L. Date: 12/03/2026. Seat: Coach 4, 12A. Total: KES 1,500.',
            onDeny: () => Navigator.pop(context),
            onAllow: () {
              Navigator.pop(context);
              // Hide the prompt after importing
              setState(() => _hasPendingSMS = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(backgroundColor: Colors.green, content: Text('Ticket successfully imported!'))
              );
            },
          ),
        );     
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withAlpha(80), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('New SGR Ticket Detected', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                SizedBox(height: 4),
                Text('Tap to import from SMS', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }

  // 3. UPDATED CURRENT JOURNEY CARD MATCHING FIGMA
  Widget _buildCurrentJourneyCard() {
    // Mocked multi-segment journey data based on your Figma file
    final journeySegments = [
      {'location': 'Nairobi CBD', 'time': '07:00', 'icon': Icons.location_on, 'status': 'passed'},
      {'location': 'Nairobi Central Station', 'time': '08:00', 'icon': Icons.train, 'status': 'active'},
      {'location': 'Mombasa SGR Station', 'time': '12:30', 'icon': Icons.location_on, 'status': 'future'},
      {'location': 'Moi International Airport', 'time': '16:00', 'icon': Icons.flight, 'status': 'future'},
      {'location': 'Johannesburg OR Tambo', 'time': '19:45', 'icon': Icons.flight, 'status': 'future'},
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6D00), width: 2),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Current Journey', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A237E))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFF6D00), borderRadius: BorderRadius.circular(20)),
                child: const Text('IN PROGRESS', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Render the timeline
          ...List.generate(journeySegments.length, (index) {
            final segment = journeySegments[index];
            return _buildTimelineSegment(
              location: segment['location'] as String,
              time: segment['time'] as String,
              icon: segment['icon'] as IconData,
              isPassed: segment['status'] == 'passed',
              isActive: segment['status'] == 'active',
              isLast: index == journeySegments.length - 1,
            );
          }),
        ],
      ),
    );
  }

  // 4. VERTICAL TIMELINE LOGIC
  Widget _buildTimelineSegment({
    required String location,
    required String time,
    required IconData icon,
    required bool isPassed,
    required bool isActive,
    required bool isLast,
  }) {
    final color = isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade400;

    return IntrinsicHeight( // Ensures the vertical line stretches to fill the row height
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left side: Line and Dot
          SizedBox(
            width: 32,
            child: Column(
              children: [
                // The Dot
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                ),
                // The Vertical Line (hide on the last item)
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          
          // Right side: Icon, Location, Time
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28.0), // Spacing between timeline nodes
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFF1A237E) : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}