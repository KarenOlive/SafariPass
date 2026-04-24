import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../widgets/boarding_pass_card.dart';

class TicketDetailScreen extends StatefulWidget {
  final Map<String, dynamic> ticket;

  const TicketDetailScreen({super.key, required this.ticket});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  bool _isHighBrightness = false;
  Timer? _timer;
  Duration? _countdown;
  DateTime? _departureTime;
  bool _isPast = false;
  bool _isUpcoming = false;

  @override
  void initState() {
    super.initState();
    _initCountdown();
  }

  void _initCountdown() {
    // Parse the real departure time from the ticket
    final rawDeparture = widget.ticket['departure'];
    if (rawDeparture != null) {
      try {
        _departureTime = DateTime.parse(rawDeparture);
        final now = DateTime.now();

        if (_departureTime!.isBefore(now)) {
          // Departure is in the past
          _isPast = true;
        } else {
          // Departure is upcoming — start real countdown
          _isUpcoming = true;
          _countdown = _departureTime!.difference(now);

          _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
            final remaining = _departureTime!.difference(DateTime.now());
            if (remaining.isNegative) {
              setState(() {
                _isPast = true;
                _isUpcoming = false;
              });
              _timer?.cancel();
            } else {
              setState(() {
                _countdown = remaining;
              });
            }
          });
        }
      } catch (_) {
        // If date can't be parsed, don't show countdown
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.ticket['status'] ?? 'upcoming';
    final isCurrent = (status == 'current' || status == 'confirmed') && !_isPast;

    return Scaffold(
      backgroundColor: _isHighBrightness ? Colors.white : const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2151),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.ticket['carrier'] ?? 'Ticket Details',
            style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dark blue background extension
            Container(height: 40, width: double.infinity, color: const Color(0xFF1A2151)),

            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // ── Status Banner ────────────────────────────────────────
                    if (_isPast)
                      _buildPastBanner()
                    else if (_isUpcoming && _countdown != null)
                      _buildCountdownCard()
                    else if (isCurrent)
                      _buildCountdownCard(),

                    // ── Boarding Pass ────────────────────────────────────────
                    BoardingPassCard(
                      ticket: widget.ticket,
                      isHighBrightness: _isHighBrightness,
                    ),

                    const SizedBox(height: 24),

                    // ── Brightness Toggle ────────────────────────────────────
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2151),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => setState(() => _isHighBrightness = !_isHighBrightness),
                      child: Text(
                        _isHighBrightness ? '☀️ High Brightness ON' : '🔆 Enable High Brightness',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ── Action buttons (only for active/upcoming tickets) ────
                    if (isCurrent) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          side: const BorderSide(color: Color(0xFF1A2151), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.map, color: Color(0xFF1A2151)),
                        label: const Text('View Terminal Map',
                            style: TextStyle(color: Color(0xFF1A2151), fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {},
                      ),
                    ],

                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Countdown card (real-time, for upcoming tickets) ──────────────────────
  Widget _buildCountdownCard() {
    final gateMinutes = _countdown != null ? (_countdown!.inMinutes - 30) : 0;
    final gateText = gateMinutes > 0
        ? 'Gate closes in ~$gateMinutes min'
        : 'Boarding soon — head to your gate!';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF27121), width: 2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF27121).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          const Text(
            'TIME TO DEPARTURE',
            style: TextStyle(color: Color(0xFFF27121), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 8),
          Text(
            _countdown != null ? _formatDuration(_countdown!) : '--:--',
            style: const TextStyle(
              color: Color(0xFF1A2151),
              fontSize: 44,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.access_time, color: Color(0xFFF27121), size: 16),
              const SizedBox(width: 8),
              Text(gateText, style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Past banner (for tickets whose departure date has passed) ─────────────
  Widget _buildPastBanner() {
    final depTime = _departureTime;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: Colors.grey, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PAST JOURNEY',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  depTime != null
                      ? 'Departed ${DateFormat('dd MMM yyyy, HH:mm').format(depTime)}'
                      : 'This journey has already departed.',
                  style: const TextStyle(
                    color: Color(0xFF1A2151),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}