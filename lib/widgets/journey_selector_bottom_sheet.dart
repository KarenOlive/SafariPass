import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';

Future<String?> showJourneySelector(BuildContext context, String userId) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => JourneySelectorBottomSheet(userId: userId),
  ).then((selected) async {
    if (selected == 'CREATE_NEW') {
      return _createNewJourney(context, userId);
    }
    return selected;
  });
}

class JourneySelectorBottomSheet extends StatelessWidget {
  final String userId;
  const JourneySelectorBottomSheet({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Journey',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A2151)),
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.getAllJourneys(userId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final journeys = snapshot.data ?? [];
              return SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: journeys.length + 1,
                  itemBuilder: (ctx, index) {
                    if (index == journeys.length) {
                      return ListTile(
                        leading: const Icon(Icons.add, color: Color(0xFFF27121)),
                        title: const Text('Create New Journey'),
                        onTap: () => Navigator.pop(context, 'CREATE_NEW'),
                      );
                    }
                    final journey = journeys[index];
                    return ListTile(
                      title: Text(journey['title'] ?? 'Unnamed Journey'),
                      subtitle: Text('${journey['start_date']} – ${journey['end_date']}'),
                      onTap: () => Navigator.pop(context, journey['journey_id']),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String> _createNewJourney(BuildContext context, String userId) async {
  final now = DateTime.now();
  final startDate = DateTime(now.year, now.month, now.day);
  final endDate = startDate.add(const Duration(days: 1));

  String? title = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New Journey'),
      content: TextField(
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Enter a name (e.g., "Mombasa Trip")'),
        onSubmitted: (value) => Navigator.pop(ctx, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, null), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(ctx, ''),
          child: const Text('Skip'),//should be able to skip and just use default title with date
        ),
      ],
    ),
  );

  if (title == null) return ''; // cancelled

  final journeyId = await DatabaseHelper.instance.createJourney(
    userID: userId,
    title: title.isEmpty ? 'Trip ${DateFormat.yMMMd().format(now)}' : title,
    startDate: startDate,
    endDate: endDate,
    status: 'upcoming',
  );
  return journeyId;
}