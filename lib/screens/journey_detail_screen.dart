import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/flight_status_service.dart';
import 'ticket_detail_screen.dart';
import 'package:intl/intl.dart';

class JourneyDetailScreen extends StatefulWidget {
  final String journeyId;

  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  State<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends State<JourneyDetailScreen> {
  bool _isLoading = true;
  bool _isFetchingUpdates = false;
  Map<String, dynamic>? _journey;
  List<Map<String, dynamic>> _tickets = [];

  @override
  void initState() {
    super.initState();
    _loadJourney();
  }

  Future<void> _loadJourney() async {
    final fullJourney = await DatabaseHelper.instance.getFullJourney(widget.journeyId);
    setState(() {
      _journey = fullJourney['journey'];
      _tickets = List<Map<String, dynamic>>.from(fullJourney['tickets'] ?? []);
      _isLoading = false;
    });
  }

  Future<void> _fetchFlightUpdates() async {
    setState(() => _isFetchingUpdates = true);

    try {
      final statusUpdates = await FlightStatusService().fetchFlightStatusBatch(_tickets);

      if (statusUpdates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ No flight data available or all tickets are non-flight.')),
          );
        }
        return;
      }

      // Update tickets in database
      for (final entry in statusUpdates.entries) {
        final ticketId = entry.key;
        final status = entry.value;

        // Update ticket with new status info
        final db = (await DatabaseHelper.instance.database);
        final updateData = {'last_modified': DateTime.now().toIso8601String(), 'isSynced': 0};

        if (status['status'] != null) updateData['status'] = status['status'];
        if (status['delay'] != null) updateData['delay'] = status['delay'];
        if (status['gate'] != null) updateData['gate'] = status['gate'];

        await db.update(
          'ticket',
          updateData,
          where: 'ticket_id = ?',
          whereArgs: [ticketId],
        );
      }

      // Reload journey with updated tickets
      await _loadJourney();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Updated ${statusUpdates.length} flight(s)'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingUpdates = false);
      }
    }
  }

  // ── Status helpers ──────────────────────────────────────────────────────────
  String _statusLabel(String status) {
    switch (status) {
      case 'ongoing': return 'IN PROGRESS';
      case 'completed': return 'COMPLETED';
      default: return 'STATUS';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ongoing': return const Color(0xFFF27121);
      case 'completed': return const Color(0xFF27AE60);
      default: return const Color(0xFF3A7FD5);
    }
  }

  IconData _carrierIcon(String? carrier) {
    final c = (carrier ?? '').toLowerCase();
    if (c.contains('flight') || c.contains('air') || c.contains('jet') || c.contains('link')) return Icons.flight;
    if (c.contains('sgr') || c.contains('train') || c.contains('rail') || c.contains('madaraka')) return Icons.train;
    if (c.contains('bus') || c.contains('coast') || c.contains('mash') || c.contains('tahmeed')) return Icons.directions_bus;
    return Icons.confirmation_number;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF1A2151),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFFF27121))),
      );
    }

    if (_journey == null) {
      return Scaffold(
        appBar: AppBar(backgroundColor: const Color(0xFF1A2151), foregroundColor: Colors.white),
        body: const Center(child: Text('Journey not found')),
      );
    }

    final status = _journey!['derived_status'] ?? _journey!['status'] ?? 'upcoming';
    final startDate = DateTime.parse(_journey!['start_date']);
    final endDate = DateTime.parse(_journey!['end_date']);
    final durationDays = endDate.difference(startDate).inDays + 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF1A2151),
            foregroundColor: Colors.white,
            actions: [
              // Fetch Flight Updates Button
              if (_tickets.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Center(
                    child: _isFetchingUpdates
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.refresh),
                            tooltip: 'Fetch flight updates',
                            onPressed: _isFetchingUpdates ? null : _fetchFlightUpdates,
                          ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A2151), Color(0xFF2C3A7A)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _statusColor(status), width: 1),
                          ),
                          child: Text(
                            _statusLabel(status),
                            style: TextStyle(
                              color: _statusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _journey!['title'] ?? 'Unnamed Journey',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Colors.white60, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '${DateFormat('dd MMM').format(startDate)} – ${DateFormat('dd MMM yyyy').format(endDate)}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.white38,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Icon(Icons.access_time, color: Colors.white60, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              '$durationDays day${durationDays != 1 ? 's' : ''}',
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Stats Row ──────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                children: [
                  _buildStatChip(
                    Icons.confirmation_number_outlined,
                    '${_tickets.length}',
                    'Ticket${_tickets.length != 1 ? 's' : ''}',
                  ),
                  const SizedBox(width: 12),
                  if (_tickets.isNotEmpty) ...[
                    _buildStatChip(
                      Icons.flight_takeoff,
                      _tickets.first['origin'] ?? '—',
                      'Origin',
                    ),
                    const SizedBox(width: 12),
                    _buildStatChip(
                      Icons.flight_land,
                      _tickets.last['destination'] ?? '—',
                      'Destination',
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Tickets Section ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Row(
                children: [
                  const Text(
                    'Tickets',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A2151),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_tickets.length} total',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),

          if (_tickets.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27121).withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.confirmation_number_outlined,
                          color: Color(0xFFF27121), size: 32),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No tickets yet',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1A2151)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Scan a ticket or import from SMS\nto add it to this journey.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey[500], height: 1.5),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _buildTicketCard(_tickets[index], index),
                ),
                childCount: _tickets.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFFF27121), size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A2151),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(Map<String, dynamic> ticket, int index) {
    final departure = ticket['departure'] != null ? DateTime.parse(ticket['departure']) : null;
    final arrival = ticket['arrival'] != null ? DateTime.parse(ticket['arrival']) : null;
    final origin = (ticket['origin'] ?? 'Unknown').toString().toUpperCase();
    final destination = (ticket['destination'] ?? 'Unknown').toString().toUpperCase();
    final carrier = ticket['carrier'] ?? 'Unknown Carrier';
    final pnr = ticket['pnr'] ?? '';
    final seat = ticket['seat'] ?? '';
    final status = ticket['status'] as String?; // Flight status from Aviation Stack
    final delay = ticket['delay'] as int?; // Delay in minutes
    final gate = ticket['gate'] as String?; // Gate number

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => TicketDetailScreen(ticket: ticket)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            // Top: Route row with status
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  // Carrier icon bubble
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2151).withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_carrierIcon(carrier), color: const Color(0xFF1A2151), size: 22),
                  ),
                  const SizedBox(width: 14),
                  // Route
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              origin.length > 4 ? origin.substring(0, 3) : origin,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2151),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                children: [
                                  Container(width: 16, height: 1.5, color: Colors.grey[300]),
                                  const Icon(Icons.circle, size: 6, color: Color(0xFFF27121)),
                                  Container(width: 16, height: 1.5, color: Colors.grey[300]),
                                ],
                              ),
                            ),
                            Text(
                              destination.length > 4 ? destination.substring(0, 3) : destination,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A2151),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          carrier,
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                  // Flight status badge if available
                  if (status != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _flightStatusColor(status).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _flightStatusColor(status), width: 1),
                      ),
                      child: Text(
                        _formatFlightStatus(status),
                        style: TextStyle(
                          color: _flightStatusColor(status),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const Icon(Icons.chevron_right, color: Color(0xFFF27121)),
                ],
              ),
            ),
            // Divider with notch effect
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F6FB),
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Wrap(
                        children: List.generate(
                          (constraints.maxWidth / 10).floor(),
                          (i) => Container(
                            width: 5,
                            height: 1.5,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            color: Colors.grey[200],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF4F6FB),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            // Bottom: Time + PNR + seat + delay/gate
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (departure != null) ...[
                        _infoChip(Icons.schedule, DateFormat('dd MMM, HH:mm').format(departure)),
                        const SizedBox(width: 10),
                      ],
                      if (arrival != null) ...[
                        _infoChip(Icons.flag_outlined, DateFormat('HH:mm').format(arrival)),
                        const SizedBox(width: 10),
                      ],
                      if (pnr.isNotEmpty) _infoChip(Icons.tag, pnr),
                      if (seat.isNotEmpty) ...[
                        const SizedBox(width: 10),
                        _infoChip(Icons.airline_seat_recline_normal, 'Seat $seat'),
                      ],
                    ],
                  ),
                  // Display delay and gate if available
                  if (delay != null || gate != null) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (delay != null) ...[
                          _infoChip(
                            Icons.timer,
                            delay > 0 ? 'Delayed ${delay}m' : 'On time',
                            color: delay > 0 ? Colors.red : Colors.green,
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (gate != null) _infoChip(Icons.meeting_room, 'Gate $gate'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFlightStatus(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return 'Scheduled';
      case 'active':
        return 'In Air';
      case 'landed':
        return 'Landed';
      case 'cancelled':
        return 'Cancelled';
      case 'delayed':
        return 'Delayed';
      default:
        return status;
    }
  }

  Color _flightStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'scheduled':
        return const Color(0xFF3A7FD5);
      case 'active':
        return const Color(0xFFF27121);
      case 'landed':
        return const Color(0xFF27AE60);
      case 'cancelled':
        return const Color(0xFFE74C3C);
      case 'delayed':
        return const Color(0xFFF39C12);
      default:
        return const Color(0xFF95A5A6);
    }
  }

  Widget _infoChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color ?? Colors.grey[400]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: color ?? Colors.grey[600])),
      ],
    );
  }
}
