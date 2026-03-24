import 'package:flutter/material.dart';

class TimelineSegment extends StatelessWidget {
  final String location;
  final String time;
  final IconData icon;
  final bool isPassed;
  final bool isActive;
  final bool isLast;

  const TimelineSegment({
    super.key,
    required this.location,
    required this.time,
    required this.icon,
    required this.isPassed,
    required this.isActive,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade400;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            location,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFF1A237E) : Colors.grey.shade500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isPassed ? const Color(0xFF4CAF50) : isActive ? const Color(0xFFFF6D00) : Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}