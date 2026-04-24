import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class JourneyCard extends StatelessWidget {
  final Map<String, dynamic> journey;
  final VoidCallback? onTap;

  const JourneyCard({super.key, required this.journey, this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = journey['title'] ?? 'Unnamed Journey';
    final startDate = DateTime.parse(journey['start_date']);
    final endDate = DateTime.parse(journey['end_date']);
    final status = journey['derived_status'] ?? journey['status'] ?? 'upcoming';

    String statusText;
    Color statusColor;
    switch (status) {
      case 'ongoing':
        statusText = 'IN PROGRESS';
        statusColor = const Color(0xFFF27121);
        break;
      case 'completed':
        statusText = 'COMPLETED';
        statusColor = Colors.green;
        break;
      default:
        statusText = 'UPCOMING';
        statusColor = Colors.blue;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${DateFormat('dd MMM yyyy').format(startDate)} – ${DateFormat('dd MMM yyyy').format(endDate)}',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}