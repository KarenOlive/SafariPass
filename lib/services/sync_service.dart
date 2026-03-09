import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'database_helper.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  Future<void> syncUnsyncedRecords() async {
    // 1. Check connectivity
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final dbHelper = DatabaseHelper.instance;

    // 2. Fetch unsynced tickets
    final unsyncedTickets = await dbHelper.getUnsyncedTickets();
    for (var ticket in unsyncedTickets) {
      await _syncTicket(ticket);
    }

    // 3. Fetch unsynced journeys (and other entities) similarly
    final unsyncedJourneys = await dbHelper.getUnsyncedJourneys();
    for (var journey in unsyncedJourneys) {
      await _syncJourney(journey);
    }

    // 4. connections and ai queue
    final unsyncedConnections = await dbHelper.getUnsyncedConnections();
    for (var conn in unsyncedConnections) {
      await _syncConnection(conn);
    }
    final unsyncedQueues = await dbHelper.getPendingAITasks();
    for (var q in unsyncedQueues) {
      await _syncAiQueue(q);
    }
  }

  Future<void> _syncTicket(Map<String, dynamic> ticket) async {
    try {
      // Call Firebase Function that handles ticket sync
      final function = FirebaseFunctions.instance.httpsCallable('syncTicket');
      final result = await function.call(ticket);

      if (result.data['success'] == true) {
        // Mark as synced in local DB
        await DatabaseHelper.instance.markTicketAsSynced(ticket['ticket_id']);
      }
    } catch (e) {
      print('Sync error for ticket ${ticket['ticket_id']}: $e');
    }
  }

  Future<void> _syncJourney(Map<String, dynamic> journey) async {
   try {
      final function = FirebaseFunctions.instance.httpsCallable('syncJourney');
      final result = await function.call(journey);
      if (result.data != null && result.data['success'] == true) {
        await DatabaseHelper.instance.markJourneyAsSynced(journey['journey_id']);
      }
    } catch (e, st) {
      print('Sync error for journey ${journey['journey_id']}: $e\n$st');
    }
  }

  Future<void> _syncConnection(Map<String, dynamic> connection) async {
    try {
      final function = FirebaseFunctions.instance.httpsCallable('syncConnection');
      final result = await function.call(connection);
      if (result.data != null && result.data['success'] == true) {
        await DatabaseHelper.instance.markConnectionAsSynced(connection['connection_id']);
      }
    } catch (e, st) {
      print('Sync error for connection ${connection['connection_id']}: $e\n$st');
    }
  }

  Future<void> _syncAiQueue(Map<String, dynamic> queue) async {
    try {
      final function = FirebaseFunctions.instance.httpsCallable('processAiQueueItem');
      final result = await function.call(queue);
          if (result.data != null && result.data['success'] == true) {
            // update local task status if needed
            await DatabaseHelper.instance.updateAITaskResult(
              queue['queue_id'],
              status: 'completed',
              resultJson: result.data['result']?.toString(),
            );
          }
        } catch (e, st) {
          print('Sync error for ai queue ${queue['queue_id']}: $e\n$st');
        }

      }
}