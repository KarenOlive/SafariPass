import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'database_helper.dart';
import 'flight_status_service.dart';

/// Syncs unsynced local SQLite records directly to Firestore.
/// Uses the Firestore SDK which automatically attaches the current user's
/// auth token — no Cloud Functions relay required.
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> syncUnsyncedRecords() async {
    print('🔄 Sync starting...');
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('❌ Sync skipped: no authenticated user');
        return;
      }

      // Force refresh token so Firestore has the latest credentials
      try {
        print('🔑 Refreshing auth token for ${user.uid}...');
        await user.getIdToken(true).timeout(const Duration(seconds: 10));
        print('✅ Auth token refreshed');
      } catch (e) {
        print('⚠️ Token refresh failed: $e. Proceeding with existing credentials.');
      }

      // Check connectivity
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.isEmpty ||
          connectivity.every((r) => r == ConnectivityResult.none)) {
        print('❌ Sync skipped: no internet connection');
        return;
      }

      final uid = user.uid;
      print('🚀 Starting sync for UID: $uid');
      final dbHelper = DatabaseHelper.instance;

      // 1. Sync user profile
      final unsyncedUsers = await dbHelper.getUnsyncedUsers();
      print('📊 Unsynced users: ${unsyncedUsers.length}');
      for (final u in unsyncedUsers) {
        await _upsertUser(uid, u);
      }

      // 2. Sync journeys FIRST (parent must exist before children)
      final unsyncedJourneys = await dbHelper.getUnsyncedJourneys();
      print('📊 Unsynced journeys: ${unsyncedJourneys.length}');
      for (final journey in unsyncedJourneys) {
        await _upsertJourney(uid, journey);
      }

      // 3. Sync tickets (safe — parent journey already in Firestore)
      final unsyncedTickets = await dbHelper.getUnsyncedTickets();
      print('📊 Unsynced tickets: ${unsyncedTickets.length}');
      for (final ticket in unsyncedTickets) {
        await _upsertTicket(uid, ticket);
      }

      // 4. Sync connections
      final unsyncedConnections = await dbHelper.getUnsyncedConnections();
      print('📊 Unsynced connections: ${unsyncedConnections.length}');
      for (final conn in unsyncedConnections) {
        await _upsertConnection(uid, conn);
      }

      // 5. Sync AI Processing Queue
      final unsyncedQueues = await dbHelper.getUnsyncedAiQueue();
      print('📊 Unsynced AI queue items: ${unsyncedQueues.length}');
      for (final q in unsyncedQueues) {
        await _upsertAiQueue(uid, q);
      }

      // 6. [HYBRID] Auto-update flights departing within 24 hours
      await _autoUpdateUpcomingFlights(uid, dbHelper);

      print('✨ Sync cycle complete');
    } catch (e, st) {
      print('💥 FATAL ERROR during sync: $e\n$st');
    }
  }

  // ── Auto-update upcoming flights (Hybrid approach) ────────────────────────

  Future<void> _autoUpdateUpcomingFlights(String uid, DatabaseHelper dbHelper) async {
    try {
      print('🔍 [HYBRID] Checking for flights departing within 24 hours...');

      // Get all journeys for user
      final journeys = await dbHelper.getAllJourneys(uid);
      if (journeys.isEmpty) {
        print('ℹ️ No journeys found');
        return;
      }

      final now = DateTime.now();
      final tomorrow = now.add(const Duration(hours: 24));
      final upcomingTickets = <Map<String, dynamic>>[];

      // Find flights departing within next 24 hours
      for (final journey in journeys) {
        final tickets = await dbHelper.getTicketsForJourney(journey['journey_id']);
        for (final ticket in tickets) {
          final departure = ticket['departure'] != null ? DateTime.parse(ticket['departure']) : null;

          // Include flights that:
          // - Haven't departed yet (in future)
          // - Depart within 24 hours
          // - Are actual flights (not trains/buses)
          if (departure != null && departure.isAfter(now) && departure.isBefore(tomorrow)) {
            final carrier = (ticket['carrier'] ?? '').toString().toLowerCase();
            if (!carrier.contains('sgr') &&
                !carrier.contains('train') &&
                !carrier.contains('bus') &&
                !carrier.contains('coast') &&
                !carrier.contains('mash')) {
              upcomingTickets.add(ticket);
            }
          }
        }
      }

      if (upcomingTickets.isEmpty) {
        print('✅ No upcoming flights to check');
        return;
      }

      print('🛫 Found ${upcomingTickets.length} flight(s) departing within 24h - fetching status...');

      // Batch fetch flight statuses
      final statusUpdates = await FlightStatusService().fetchFlightStatusBatch(upcomingTickets);

      if (statusUpdates.isEmpty) {
        print('ℹ️ No flight status data available');
        return;
      }

      // Update tickets silently (no UI notification during sync)
      for (final entry in statusUpdates.entries) {
        final ticketId = entry.key;
        final status = entry.value;

        final db = await dbHelper.database;
        final updateData = {'last_modified': DateTime.now().toIso8601String(), 'isSynced': 0};

        if (status['status'] != null) updateData['status'] = status['status'];
        if (status['delay'] != null) updateData['delay'] = status['delay'];
        if (status['gate'] != null) updateData['gate'] = status['gate'];

        await db.update(
          'ticket',
          updateData,
          where: 'ticket_id = ?',
          whereArgs: [ticketId],
        );
      }

      print('✅ [HYBRID] Updated ${statusUpdates.length} flight status(es) during sync');
    } catch (e, st) {
      debugPrint('⚠️ [HYBRID] Auto-update failed (non-fatal): $e\n$st');
      // Don't throw - this is optional background work
    }
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _upsertUser(String uid, Map<String, dynamic> user) async {
    try {
      final ref = _db.collection('users').doc(uid);

      // Rules: user_id, name, phone_hash, created_at, last_modified, isSynced
      final payload = {
        'user_id': uid,
        'name': user['name'] ?? '',
        'phone_hash': user['phone_hash'] ?? '',
        'created_at': user['created_at'] ?? DateTime.now().toIso8601String(),
        'last_modified': user['last_modified'] ?? DateTime.now().toIso8601String(),
        'isSynced': true,
      };

      await ref.set(payload, SetOptions(merge: true));
      await DatabaseHelper.instance.markUserAsSynced(user['user_id']);
      print('✅ User profile synced: $uid');
    } catch (e, st) {
      print('❌ Sync error for user $uid: $e\n$st');
    }
  }

  Future<void> _upsertJourney(String uid, Map<String, dynamic> journey) async {
    final journeyId = journey['journey_id'];
    try {
      final ref = _db.collection('journeys').doc(journeyId);

      // Conflict check: only write if incoming is newer
      final snap = await ref.get();
      if (snap.exists) {
        final serverModified = snap.data()?['last_modified'] ?? '';
        final incomingModified = journey['last_modified'] ?? '';
        if (serverModified.compareTo(incomingModified) > 0) {
          print('⏭ Skipping journey $journeyId — server is newer');
          await DatabaseHelper.instance.markJourneyAsSynced(journeyId);
          return;
        }
      }

      // Rules: journey_id, user_id, title, start_date, end_date, status, last_modified, isSynced
      final payload = {
        'journey_id': journeyId,
        'user_id': uid, // Ensure it matches request.auth.uid
        'title': journey['title'] ?? 'My Journey',
        'start_date': journey['start_date'],
        'end_date': journey['end_date'],
        'status': journey['status'] ?? 'upcoming',
        'last_modified': journey['last_modified'],
        'isSynced': true,
      };

      await ref.set(payload, SetOptions(merge: true));
      await DatabaseHelper.instance.markJourneyAsSynced(journeyId);
      print('✅ Journey synced: $journeyId');
    } catch (e, st) {
      print('❌ Sync error for journey $journeyId: $e\n$st');
    }
  }

  Future<void> _upsertTicket(String uid, Map<String, dynamic> ticket) async {
    final ticketId = ticket['ticket_id'];
    try {
      final ref = _db.collection('tickets').doc(ticketId);

      // Rules: ticket_id, journey_id, user_id, carrier, pnr, departure, arrival, 
      // origin, destination, seat, source_type, raw_data, image_path, confidence_score, 
      // status, last_modified, isSynced
      final payload = {
        'ticket_id': ticketId,
        'journey_id': ticket['journey_id'],
        'user_id': uid, // Mandatory for rules
        'carrier': ticket['carrier'],
        'pnr': ticket['pnr'] ?? '',
        'departure': ticket['departure'],
        'arrival': ticket['arrival'],
        'origin': ticket['origin'],
        'destination': ticket['destination'],
        'seat': ticket['seat'] ?? '',
        'source_type': ticket['source_type'],
        'raw_data': ticket['raw_data'] ?? '',
        'image_path': ticket['image_path'] ?? '',
        'confidence_score': (ticket['confidence_score'] as num?)?.toDouble() ?? 1.0,
        'status': ticket['status'] ?? 'confirmed',
        'last_modified': ticket['last_modified'],
        'isSynced': true,
      };

      await ref.set(payload, SetOptions(merge: true));
      await DatabaseHelper.instance.markTicketAsSynced(ticketId);
      print('✅ Ticket synced: $ticketId');
    } catch (e, st) {
      print('❌ Sync error for ticket $ticketId: $e\n$st');
    }
  }

  Future<void> _upsertConnection(String uid, Map<String, dynamic> connection) async {
    final connectionId = connection['connection_id'];
    try {
      final ref = _db.collection('connections').doc(connectionId);

      // Rules: connection_id, journey_id, user_id, from_ticket_id, to_ticket_id, transport_type, 
      // estimated_duration, status, last_modified, isSynced
      final payload = {
        'connection_id': connectionId,
        'journey_id': connection['journey_id'],
        'user_id': uid,
        'from_ticket_id': connection['from_ticket_id'],
        'to_ticket_id': connection['to_ticket_id'],
        'transport_type': connection['transport_type'],
        'estimated_duration': connection['estimated_duration']?.toString() ?? '',
        'status': connection['status'] ?? 'planned',
        'last_modified': connection['last_modified'],
        'isSynced': true,
      };

      await ref.set(payload, SetOptions(merge: true));
      await DatabaseHelper.instance.markConnectionAsSynced(connectionId);
      print('✅ Connection synced: $connectionId');
    } catch (e, st) {
      print('❌ Sync error for connection $connectionId: $e\n$st');
    }
  }

  Future<void> _upsertAiQueue(String uid, Map<String, dynamic> queue) async {
    final queueId = queue['queue_id'];
    try {
      final ref = _db.collection('ai_processing_queue').doc(queueId);

      // Rules: queue_id, ticket_id, user_id, image_data, queued_at, status, result_json, last_modified, isSynced
      final payload = {
        'queue_id': queueId,
        'ticket_id': queue['ticket_id'],
        'user_id': uid,
        'image_data': queue['image_data'],
        'queued_at': queue['queued_at'],
        'status': queue['status'] ?? 'pending',
        'result_json': queue['result_json'] ?? '',
        'last_modified': queue['last_modified'],
        'isSynced': true,
      };

      await ref.set(payload, SetOptions(merge: true));
      await DatabaseHelper.instance.markAiQueueAsSynced(queueId);
      print('✅ AI Queue item synced: $queueId');
    } catch (e, st) {
      print('❌ Sync error for ai_queue $queueId: $e\n$st');
    }
  }
}