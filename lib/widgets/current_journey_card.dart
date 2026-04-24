import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

  // Journey-level date awareness
  bool _isJourneyPast = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    final fullJourney = await DatabaseHelper.instance.getFullJourney(widget.journeyId);
    final journey = fullJourney['journey'] as Map<String, dynamic>?;
    final tickets = List<Map<String, dynamic>>.from(fullJourney['tickets'] ?? []);

    // Sort tickets by departure time (ascending)
    tickets.sort((a, b) => (a['departure'] ?? '').compareTo(b['departure'] ?? ''));

    // Determine if the whole journey is past based on end_date
    bool isPast = false;
    if (journey != null && journey['end_date'] != null) {
      try {
        final endDate = DateTime.parse(journey['end_date']);
        isPast = DateTime.now().isAfter(endDate);
      } catch (_) {}
    }

    // Fallback: if no journey end_date, check if ALL ticket departures are past
    if (!isPast && tickets.isNotEmpty) {
      isPast = tickets.every((t) {
        try {
          return t['departure'] != null &&
              DateTime.now().isAfter(DateTime.parse(t['departure']));
        } catch (_) {
          return false;
        }
      });
    }

    setState(() {
      _tickets = tickets;
      _isJourneyPast = isPast;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _isJourneyPast ? Colors.grey.shade300 : const Color(0xFFF27121),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isJourneyPast
                ? Colors.black.withValues(alpha: 0.04)
                : const Color(0xFFF27121).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isJourneyPast ? 'Past Journey' : 'Current Journey',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: _isJourneyPast ? Colors.grey[600] : const Color(0xFF1A2151),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isJourneyPast ? 'This journey has ended' : 'Active right now',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
              _isJourneyPast
                  ? _buildPastBadge()
                  : _buildInProgressBadge(),
            ],
          ),
          const SizedBox(height: 28),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_tickets.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No tickets yet for this journey',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ),
            )
          else
            ..._buildSegments(),
        ],
      ),
    );
  }

  Widget _buildInProgressBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF27121),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF27121).withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Text(
        'IN PROGRESS',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildPastBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 13, color: Colors.grey[500]),
          const SizedBox(width: 5),
          Text(
            'COMPLETED',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
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
      DateTime? departure;
      try {
        departure = ticket['departure'] != null ? DateTime.parse(ticket['departure']) : null;
      } catch (_) {}

      final origin = ticket['origin'] ?? '?';
      final departureTime = departure != null
          ? DateFormat('HH:mm').format(departure)
          : '--:--';

      final bool isPassed = departure != null && now.isAfter(departure);
      final bool isActive = !isPassed &&
          (i == 0 ||
              (_tickets[i - 1]['departure'] != null &&
                  now.isAfter(DateTime.parse(_tickets[i - 1]['departure']))));

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

      // If last ticket, add the final destination segment
      if (i == ticketCount - 1) {
        DateTime? arrival;
        try {
          arrival = ticket['arrival'] != null ? DateTime.parse(ticket['arrival']) : null;
        } catch (_) {}

        final arrivalTime = arrival != null ? DateFormat('HH:mm').format(arrival) : '';
        widgets.add(
          TimelineSegment(
            location: ticket['destination'] ?? '?',
            time: arrivalTime,
            icon: Icons.location_on,
            isPassed: arrival != null ? now.isAfter(arrival) : _isJourneyPast,
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
    if (lower.contains('train') || lower.contains('sgr') || lower.contains('madaraka')) {
      return Icons.train;
    }
    if (lower.contains('flight') || lower.contains('airline') ||
        lower.contains('jambojet') || lower.contains('safarilink') ||
        lower.contains('kenya airways')) {
      return Icons.flight;
    }
    if (lower.contains('bus') || lower.contains('coast') || lower.contains('mash')) {
      return Icons.directions_bus;
    }
    return Icons.directions_transit;
  }
}