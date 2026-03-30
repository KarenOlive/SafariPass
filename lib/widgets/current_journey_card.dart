import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'timeline_segment.dart';

class CurrentJourneyCard extends StatefulWidget {
  final String journeyId;
  const CurrentJourneyCard({super.key, required this.journeyId});

  @override
  State<CurrentJourneyCard> createState() => _CurrentJourneyCardState();
}

class _CurrentJourneyCardState extends State<CurrentJourneyCard> {
  List<Map<String, dynamic>> _tickets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final tickets = await DatabaseHelper.instance.getTicketsForJourney(widget.journeyId);
    // Sort tickets by departure time (ascending)
    tickets.sort((a, b) => a['departure'].compareTo(b['departure']));
    setState(() {
      _tickets = tickets;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_tickets.isEmpty)
            const Center(child: Text('No tickets yet for this journey'))
          else
            ..._buildSegments(),
        ],
      ),
    );
  }

  List<Widget> _buildSegments() {
    final now = DateTime.now();
    final List<Widget> widgets = [];
    final int ticketCount = _tickets.length;

    for (int i = 0; i < ticketCount; i++) {
      final ticket = _tickets[i];
      final departure = DateTime.parse(ticket['departure']);
      final origin = ticket['origin'] ?? '?';
      final departureTime = '${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}';
      
      // Determine segment status
      final bool isPassed = now.isAfter(departure);
      // Active segment is the first upcoming segment (or the one currently in progress)
      final bool isActive = !isPassed && (i == 0 || now.isAfter(DateTime.parse(_tickets[i-1]['departure'])));

      // Add the departure segment (origin)
      widgets.add(
        TimelineSegment(
          location: origin,
          time: departureTime,
          icon: _getIconForCarrier(ticket['carrier'] ?? ''),
          isPassed: isPassed,
          isActive: isActive,
          isLast: false,
        ),
      );

      // If this is the last ticket, also add a final destination segment (arrival)
      if (i == ticketCount - 1) {
        final arrival = ticket['arrival'] != null
            ? DateTime.parse(ticket['arrival'])
            : null;
        final arrivalTime = arrival != null
            ? '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}'
            : '';
        widgets.add(
          TimelineSegment(
            location: ticket['destination'] ?? '?',
            time: arrivalTime,
            icon: Icons.location_on,
            isPassed: arrival != null ? now.isAfter(arrival) : false,
            isActive: false,
            isLast: true,
          ),
        );
      }
    }
    return widgets;
  }

  IconData _getIconForCarrier(String carrier) {
    final lower = carrier.toLowerCase();
    if (lower.contains('train') || lower.contains('sgr')) return Icons.train;
    if (lower.contains('flight') || lower.contains('airline') || lower.contains('jambojet') || lower.contains('safarilink')) return Icons.flight;
    if (lower.contains('bus')) return Icons.directions_bus;
    return Icons.directions_transit;
  }
}