import 'package:flutter/material.dart';

class TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onClick;

  const TicketCard({super.key, required this.ticket, required this.onClick});

  // Helper to determine transport type/icon based on carrier or raw data
  IconData _getIcon() {
    final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
    if (carrier.contains('sgr') || carrier.contains('train')) return Icons.train;
    if (carrier.contains('bus') || carrier.contains('coach')) return Icons.directions_bus;
    if(carrier.contains('flight') || carrier.contains('airline')) return Icons.flight;
    return Icons.directions_transit; // Default icon for unknown types
  }

  String _getTypeLabel() {
    final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
    if (carrier.contains('sgr') || carrier.contains('train')) return 'SGR Train';
    if (carrier.contains('bus')) return 'Bus';
    return 'Flight';
  }

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] ?? 'upcoming';
    final isCurrent = status == 'current';
    final isPast = status == 'past';

    final borderColor = isCurrent ? const Color(0xFFFF6D00) : isPast ? const Color(0xFF455A64) : const Color(0xFF1A237E);
    final textColor = isPast ? const Color(0xFF455A64) : const Color(0xFF1A237E);

    // Parse dates
    DateTime? departure;
    if (ticket['departure'] != null) {
      departure = DateTime.tryParse(ticket['departure']);
    }
    final dateStr = departure != null ? "${departure.day}/${departure.month}/${departure.year}" : "TBD";
    final timeStr = departure != null ? "${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}" : "TBD";

    return GestureDetector(
      onTap: onClick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(_getIcon(), color: textColor, size: 20),
                      const SizedBox(width: 8),
                      Text(_getTypeLabel(), style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFFF6D00), borderRadius: BorderRadius.circular(20)),
                      child: const Text('ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFF4CAF50), borderRadius: BorderRadius.circular(20)),
                      child: const Text('✓ COMPLETED', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Route
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(ticket['origin'] ?? 'N/A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                  const Expanded(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Divider(color: Color(0xFF455A64), thickness: 2),
                    ),
                  ),
                  Text(ticket['destination'] ?? 'N/A', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
              const SizedBox(height: 16),

              // Details & Footer
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 14, color: Color(0xFF455A64)),
                      const SizedBox(width: 4),
                      Text(dateStr, style: const TextStyle(color: Color(0xFF455A64), fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      const Icon(Icons.access_time, size: 14, color: Color(0xFF455A64)),
                      const SizedBox(width: 4),
                      Text(timeStr, style: const TextStyle(color: Color(0xFF455A64), fontWeight: FontWeight.w600)),
                    ],
                  ),
                  if (ticket['seat'] != null && ticket['seat'].toString().isNotEmpty)
                    Text('Seat ${ticket['seat']}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}