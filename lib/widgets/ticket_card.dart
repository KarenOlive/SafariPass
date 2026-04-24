import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TicketCard extends StatelessWidget {
  final Map<String, dynamic> ticket;
  final VoidCallback onClick;

  const TicketCard({super.key, required this.ticket, required this.onClick});

  IconData _getIcon() {
    final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
    if (carrier.contains('sgr') || carrier.contains('train')) return Icons.train;
    if (carrier.contains('bus') || carrier.contains('coach')) return Icons.directions_bus;
    if (carrier.contains('flight') || carrier.contains('airline')) return Icons.flight;
    return Icons.directions_transit;
  }

  String _getTypeLabel() {
    final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
    if (carrier.contains('sgr') || carrier.contains('train')) return 'SGR Train';
    if (carrier.contains('bus')) return 'Bus';
    return 'Flight';
  }

  Color _getBorderColor() {
    final status = ticket['status'] ?? 'upcoming';
    if (status == 'current') return const Color(0xFFF27121);
    if (status == 'past') return const Color(0xFF4CAF50);
    return const Color(0xFF1A2151);
  }

  @override
  Widget build(BuildContext context) {
    final status = ticket['status'] ?? 'upcoming';
    final isCurrent = status == 'current';
    final isPast = status == 'past';
    final borderColor = _getBorderColor();

    DateTime? departure;
    if (ticket['departure'] != null) {
      departure = DateTime.tryParse(ticket['departure']);
    }
    final dateStr = departure != null
        ? DateFormat('dd MMM yyyy').format(departure)
        : "TBD";
    final timeStr = departure != null
        ? "${departure.hour.toString().padLeft(2, '0')}:${departure.minute.toString().padLeft(2, '0')}"
        : "TBD";

    return GestureDetector(
      onTap: onClick,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isPast ? Colors.grey[50] : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            BoxShadow(
              color: borderColor.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with transport type and status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: borderColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(_getIcon(), color: borderColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _getTypeLabel(),
                        style: TextStyle(
                          color: borderColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF27121),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'ACTIVE',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else if (isPast)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4CAF50),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        '✓ COMPLETED',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Route with large text and arrow
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      ticket['origin'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Icon(Icons.arrow_forward, color: borderColor, size: 24),
                  Expanded(
                    child: Text(
                      ticket['destination'] ?? 'N/A',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: borderColor,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Date and time
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    dateStr,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Divider
              Container(
                height: 1,
                color: Colors.grey[200],
              ),
              const SizedBox(height: 16),

              // Additional details (Ticket, Seat, Price)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem('Ticket', ticket['pnr'] ?? 'N/A', borderColor),
                  _buildDetailItem('Seat', ticket['seat'] ?? 'N/A', borderColor),
                  _buildDetailItem('Price', 'KES 1,000', Colors.green[700] ?? Colors.green),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
