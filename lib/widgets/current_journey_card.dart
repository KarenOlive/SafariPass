import 'package:flutter/material.dart';
import 'timeline_segment.dart';

class CurrentJourneyCard extends StatelessWidget {
  const CurrentJourneyCard({super.key});

  @override
  Widget build(BuildContext context) {
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
          ...List.generate(journeySegments.length, (index) {
            final segment = journeySegments[index];
            return TimelineSegment(
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
}