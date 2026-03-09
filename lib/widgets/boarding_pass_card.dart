import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BoardingPassCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final bool isHighBrightness;

  const BoardingPassCard({super.key, required this.ticket, required this.isHighBrightness});

  IconData _getIcon() {
    final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
    if (carrier.contains('sgr') || carrier.contains('train')) return Icons.train;
    if (carrier.contains('bus')) return Icons.directions_bus;
    return Icons.flight;
  }

  @override
  Widget build(BuildContext context) {
    DateTime? departure = ticket['departure'] != null ? DateTime.tryParse(ticket['departure']) : null;
    final dateStr = departure != null ? "${departure.day}/${departure.month}/${departure.year}" : "TBD";
    final timeStr = departure != null ? "${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}" : "TBD";
    
    // Fallback ID for the QR code if PNR is missing
    final qrData = "TICKET:${ticket['pnr'] ?? ticket['ticket_id']}-${ticket['origin']}-${ticket['destination']}";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1A237E), width: 2),
        boxShadow: isHighBrightness 
            ? [const BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 8))]
            : [const BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: Color(0xFF1A237E),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(_getIcon(), color: Colors.white, size: 24),
                    const SizedBox(width: 8),
                    Text(ticket['carrier'] ?? 'Ticket', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ticket Number', style: TextStyle(color: Colors.white70, fontSize: 10)),
                    Text(ticket['pnr'] ?? 'N/A', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                )
              ],
            ),
          ),

          // Route Section
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FROM', style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
                    Text(ticket['origin'] ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  ],
                ),
                Icon(_getIcon(), color: const Color(0xFF455A64)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TO', style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
                    Text(ticket['destination'] ?? '', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                  ],
                ),
              ],
            ),
          ),
          
          const Divider(height: 1, thickness: 2, color: Color(0xFFE0E0E0), indent: 24, endIndent: 24),

          // Travel Details Grid
          Container(
            color: Colors.grey[50],
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildDetailColumn(Icons.calendar_today, 'DATE', dateStr),
                _buildDetailColumn(Icons.access_time, 'TIME', timeStr),
                _buildDetailColumn(Icons.event_seat, 'SEAT', ticket['seat'] ?? 'TBD', isHighlight: true),
              ],
            ),
          ),

          const Divider(height: 1, thickness: 2, color: Color(0xFFE0E0E0), indent: 24, endIndent: 24),

          // QR Code Section
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              children: [
                const Text('Scan at Gate', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E), fontSize: 16)),
                const SizedBox(height: 4),
                const Text('Present this QR code for boarding', style: TextStyle(fontSize: 12, color: Color(0xFF455A64))),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(isHighBrightness ? 0x33 : 0x0D), blurRadius: 10)],
                  ),
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn(IconData icon, String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: const Color(0xFF455A64)),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF455A64))),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          fontWeight: FontWeight.bold, 
          fontSize: isHighlight ? 20 : 16, 
          color: isHighlight ? const Color(0xFFFF6D00) : const Color(0xFF1A237E)
        )),
      ],
    );
  }
}