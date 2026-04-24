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
    final color = isPassed
        ? const Color(0xFF4CAF50)
        : isActive
            ? const Color(0xFFF27121)
            : Colors.grey.shade400;

    final isUpcoming = !isPassed && !isActive;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.white : color,
                    shape: BoxShape.circle,
                    border: isUpcoming ? Border.all(color: color, width: 2) : null,
                    boxShadow: isUpcoming ? [] : [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Icon(icon, size: 18, color: color),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                location,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: isPassed
                                      ? const Color(0xFF4CAF50)
                                      : isActive
                                          ? const Color(0xFF1A2151)
                                          : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (isActive)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    'Now',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: const Color(0xFFF27121),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: color,
                      letterSpacing: -0.3,
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