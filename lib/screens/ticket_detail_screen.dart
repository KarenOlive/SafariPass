import 'package:flutter/material.dart';
import 'dart:async';
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
  Duration _countdown = const Duration(hours: 2, minutes: 45, seconds: 30); // Simulated countdown

  @override
  void initState() {
    super.initState();
    // Simulate the countdown from React's useEffect
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown.inSeconds > 0) {
        setState(() {
          _countdown = _countdown - const Duration(seconds: 1);
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    return "${twoDigits(d.inHours)}:${twoDigits(d.inMinutes.remainder(60))}:${twoDigits(d.inSeconds.remainder(60))}";
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.ticket['status'] ?? 'upcoming';
    final isCurrent = status == 'current' || status == 'confirmed'; // Assuming confirmed means active for MVP

    return Scaffold(
      backgroundColor: _isHighBrightness ? Colors.white : Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(widget.ticket['carrier'] ?? 'Ticket Details', style: const TextStyle(color: Colors.white)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Dark blue background extension behind the countdown
            Container(
              height: 40,
              width: double.infinity,
              color: const Color(0xFF1A237E),
            ),
            
            Transform.translate(
              offset: const Offset(0, -40),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  children: [
                    // Countdown Card (Only if active)
                    if (isCurrent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6D00), Color(0xFFF57C00)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))],
                        ),
                        child: Column(
                          children: [
                            const Text('TIME TO DEPARTURE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(_formatDuration(_countdown), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 2)),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.access_time, color: Colors.white, size: 16),
                                SizedBox(width: 8),
                                Text('Gate closes in 30 minutes', style: TextStyle(color: Colors.white)),
                              ],
                            )
                          ],
                        ),
                      ),

                    // The Abstracted Boarding Pass Card
                    BoardingPassCard(
                      ticket: widget.ticket,
                      isHighBrightness: _isHighBrightness,
                    ),

                    const SizedBox(height: 24),

                    // Brightness Toggle
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        minimumSize: const Size(double.infinity, 56),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isHighBrightness = !_isHighBrightness;
                        });
                        // Note: To actually change device brightness, you would add the `screen_brightness` package here.
                      },
                      child: Text(
                        _isHighBrightness ? '☀️ High Brightness ON' : '🔆 Enable High Brightness',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action Buttons
                    if (isCurrent) ...[
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          side: const BorderSide(color: Color(0xFF1A237E), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.map, color: Color(0xFF1A237E)),
                        label: const Text('View Terminal Map', style: TextStyle(color: Color(0xFF1A237E), fontSize: 16, fontWeight: FontWeight.bold)),
                        onPressed: () {},
                      ),
                      const SizedBox(height: 48), // Bottom padding
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}