import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart'; 
import 'package:firebase_auth/firebase_auth.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('safari_pass.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Open the database and enable foreign key support
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // Create all tables according to the ERD
  Future _createDB(Database db, int version) async {
    // ---- USER table ----
    await db.execute('''
      CREATE TABLE user (
        user_id TEXT PRIMARY KEY,
        name TEXT,
        phone_hash TEXT,
        created_at TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0
      )
    ''');

    // ---- JOURNEY table ----
    await db.execute('''
      CREATE TABLE journey (
        journey_id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        title TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES user (user_id) ON DELETE CASCADE
      )
    ''');

    // ---- TICKET table ----
    await db.execute('''
      CREATE TABLE ticket (
        ticket_id TEXT PRIMARY KEY,
        journey_id TEXT NOT NULL,
        carrier TEXT NOT NULL,
        pnr TEXT,
        departure TEXT NOT NULL,
        arrival TEXT,
        origin TEXT NOT NULL,
        destination TEXT NOT NULL,
        seat TEXT,
        source_type TEXT NOT NULL,
        raw_data TEXT,
        image_path TEXT,
        confidence_score REAL,
        status TEXT DEFAULT 'confirmed',
        last_modified TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        FOREIGN KEY (journey_id) REFERENCES journey (journey_id) ON DELETE CASCADE
      )
    ''');

    // ---- CONNECTION table ----
    await db.execute('''
      CREATE TABLE connection (
        connection_id TEXT PRIMARY KEY,
        journey_id TEXT NOT NULL,
        from_ticket_id TEXT,
        to_ticket_id TEXT,
        transport_type TEXT NOT NULL,
        estimated_duration TEXT,
        status TEXT NOT NULL,
        last_modified TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        FOREIGN KEY (journey_id) REFERENCES journey (journey_id) ON DELETE CASCADE,
        FOREIGN KEY (from_ticket_id) REFERENCES ticket (ticket_id) ON DELETE SET NULL,
        FOREIGN KEY (to_ticket_id) REFERENCES ticket (ticket_id) ON DELETE SET NULL
      )
    ''');

    // ---- AI_PROCESSING_QUEUE table ----
    await db.execute('''
      CREATE TABLE ai_processing_queue (
        queue_id TEXT PRIMARY KEY,
        ticket_id TEXT,
        image_data TEXT NOT NULL,
        queued_at TEXT NOT NULL,
        processed_at TEXT,
        status TEXT NOT NULL,
        result_json TEXT,
        last_modified TEXT NOT NULL,
        isSynced INTEGER DEFAULT 0,
        FOREIGN KEY (ticket_id) REFERENCES ticket (ticket_id) ON DELETE CASCADE
      )
    ''');

    // Create indexes for faster queries
    await db.execute('CREATE INDEX idx_ticket_journey ON ticket (journey_id)');
    await db.execute('CREATE INDEX idx_ticket_departure ON ticket (departure)');
    await db.execute('CREATE INDEX idx_connection_journey ON connection (journey_id)');
    await db.execute('CREATE INDEX idx_queue_status ON ai_processing_queue (status)');
    await db.execute('CREATE INDEX idx_ticket_unsynced ON ticket (isSynced) WHERE isSynced = 0');
  }

  // Helper to get current timestamp
  String _now() => DateTime.now().toIso8601String();


  // Handle database upgrades (e.g., adding new columns or tables)
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add sync columns to existing tables
      await db.execute('ALTER TABLE user ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE user ADD COLUMN isSynced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE journey ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE journey ADD COLUMN isSynced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE ticket ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE ticket ADD COLUMN isSynced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE connection ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE connection ADD COLUMN isSynced INTEGER DEFAULT 0');
      await db.execute('ALTER TABLE ai_processing_queue ADD COLUMN last_modified TEXT');
      await db.execute('ALTER TABLE ai_processing_queue ADD COLUMN isSynced INTEGER DEFAULT 0');
      
      // Optionally create new indexes
      await db.execute('CREATE INDEX IF NOT EXISTS idx_ticket_unsynced ON ticket (isSynced) WHERE isSynced = 0');
    }
  }
  // ==================== User operations ====================

  Future<String> createUser({String? name, String? phoneHash}) async {
    final db = await instance.database;
    final userID = const Uuid().v4();
    final now = _now();
    await db.insert('user', {
      'user_id': userID,
      'name': name ?? '',
      'phone_hash': phoneHash ?? '',
      'created_at': now,
      'last_modified': now,   
      'isSynced': 0, 
    });
    return userID;
  }


  Future<Map<String, dynamic>?> getUser(String userID) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'user',
      where: 'user_id = ?',
      whereArgs: [userID],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  /// Creates or updates a user record using the Firebase user ID.
/// If the user already exists (by user_id), it updates name and phone number.
/// If not, it inserts a new record.
/// After any change, `isSynced` is set to 0 to trigger cloud sync.
Future<void> createOrUpdateFirebaseUser({
  required String userId,
  String? name,
  String? phoneNumber,
}) async {
  final db = await instance.database;
  final existing = await db.query(
    'user',
    where: 'user_id = ?',
    whereArgs: [userId],
  );
  final now = _now();
  if (existing.isEmpty) {
    await db.insert('user', {
      'user_id': userId,
      'name': name ?? '',
      'phone_hash': phoneNumber ?? '',
      'created_at': now,
      'last_modified': now,
      'isSynced': 0,
    });
  } else {
    final updateData = {
      'last_modified': now,
      'isSynced': 0,
    };
    if (name != null) updateData['name'] = name;
    if (phoneNumber != null) updateData['phone_hash'] = phoneNumber;
    await db.update(
      'user',
      updateData,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }
}

/// Returns the user record for the currently logged‑in Firebase user (if any).
/// Returns null if no user is signed in or the record does not exist.
Future<Map<String, dynamic>?> getCurrentFirebaseUser() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return null;
  return getUser(user.uid);
}

  /// Returns the ID of the first user, or creates a default user if none exist.
  Future<String> getOrCreateDefaultUserId() async {
    final db = await instance.database;
    final List<Map<String, dynamic>> users = await db.query('user', limit: 1);
    if (users.isNotEmpty) {
      return users.first['user_id'] as String;
    }
    // Create a default user
    return createUser(name: 'Default User');
  }

  // ==================== Journey operations ====================

  Future<String> createJourney({
    required String userID,
    String? title,
    required DateTime startDate,
    required DateTime endDate,
    String status = 'upcoming',
  }) async {
    final db = await instance.database;
    final journeyID = const Uuid().v4();
    final now = _now();
    await db.insert('journey', {
      'journey_id': journeyID,
      'user_id': userID,
      'title': title ?? 'My Journey',
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'last_modified': now,
      'isSynced': 0,
    });
    return journeyID;
  }

  Future<List<Map<String, dynamic>>> getAllJourneys(String userID) async {
    final db = await instance.database;
    return await db.query(
      'journey',
      where: 'user_id = ?',
      whereArgs: [userID],
      orderBy: 'start_date DESC',
    );
  }

  Future<Map<String, dynamic>?> getJourney(String journeyID) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'journey',
      where: 'journey_id = ?',
      whereArgs: [journeyID],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>> getFullJourney(String journeyID) async {
    final db = await database;
    // Get journey
    final journey = await getJourney(journeyID);
    if (journey == null) return {};
    // Get tickets
    final tickets = await getTicketsForJourney(journeyID);
    // Get connections
    final connections = await getConnectionsForJourney(journeyID);
    return {
      'journey': journey,
      'tickets': tickets,
      'connections': connections,
    };
  }

Future<List<Map<String, dynamic>>> getAllJourneysWithStatus(String userID) async {
  final db = await instance.database;

  final journeysRaw = await db.query(
    'journey',
    where: 'user_id = ?',
    whereArgs: [userID],
    orderBy: 'start_date DESC',
  );

  final now = DateTime.now();

  final journeys = journeysRaw.map((journey) {
    final mutableJourney = Map<String, dynamic>.from(journey); // ✅ FIX

    final start = DateTime.parse(mutableJourney['start_date'] as String);
    final end = DateTime.parse(mutableJourney['end_date'] as String);

    if (now.isBefore(start)) {
      mutableJourney['derived_status'] = 'upcoming';
    } else if (now.isAfter(end)) {
      mutableJourney['derived_status'] = 'completed';
    } else {
      mutableJourney['derived_status'] = 'ongoing';
    }

    return mutableJourney;
  }).toList();

  return journeys;
}

  Future<int> updateJourneyStatus(String journeyID, String status) async {
    final db = await instance.database;
    return await db.update(
      'journey',
      {'status': status},
      where: 'journey_id = ?',
      whereArgs: [journeyID],
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedJourneys() async {
    final db = await instance.database;
    return await db.query(
      'journey',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'last_modified ASC',
    );
  }

  Future<int> markJourneyAsSynced(String journeyID) async {
    final db = await instance.database;
    return await db.update(
      'journey',
      {'isSynced': 1},
      where: 'journey_id = ?',
      whereArgs: [journeyID],
    );
  }

  // ==================== Ticket operations ====================

  Future<String> createTicket({
    required String journeyID,
    required String carrier,
    String? pnr,
    required DateTime departure,
    DateTime? arrival,
    required String origin,
    required String destination,
    String? seat,
    required String sourceType, // 'sms', 'image', 'pdf', 'manual'
    String? rawData,
    String? imagePath,
    double? confidenceScore,
    String status = 'confirmed',
  }) async {
    final db = await instance.database;
    final ticketID = const Uuid().v4();
    final now = _now();
    await db.insert('ticket', {
      'ticket_id': ticketID,
      'journey_id': journeyID,
      'carrier': carrier,
      'pnr': pnr ?? '',
      'departure': departure.toIso8601String(),
      'arrival': arrival?.toIso8601String(),
      'origin': origin,
      'destination': destination,
      'seat': seat ?? '',
      'source_type': sourceType,
      'raw_data': rawData ?? '',
      'image_path': imagePath ?? '',
      'confidence_score': confidenceScore,
      'status': status,
      'last_modified': now,
      'isSynced': 0,
    });
    return ticketID;
  }

  // NEW: create ticket from a map
  Future<String> createTicketFromMap(Map<String, dynamic> ticketMap) async {
    // Ensure required fields exist
    final requiredFields = ['journey_id', 'carrier', 'departure', 'origin', 'destination', 'source_type'];
    for (var field in requiredFields) {
      if (!ticketMap.containsKey(field)) throw ArgumentError('Missing $field');
    }
    // Parse dates
    final departure = DateTime.parse(ticketMap['departure']);
    final arrival = ticketMap['arrival'] != null ? DateTime.parse(ticketMap['arrival']) : null;

    return createTicket(
      journeyID: ticketMap['journey_id'],
      carrier: ticketMap['carrier'],
      pnr: ticketMap['pnr'],
      departure: departure,
      arrival: arrival,
      origin: ticketMap['origin'],
      destination: ticketMap['destination'],
      seat: ticketMap['seat'],
      sourceType: ticketMap['source_type'],
      rawData: ticketMap['raw_data'],
      imagePath: ticketMap['image_path'],
      confidenceScore: ticketMap['confidence_score']?.toDouble(),
      status: ticketMap['status'] ?? 'confirmed',
    );
  }

  // New methods for sync
  Future<List<Map<String, dynamic>>> getUnsyncedTickets() async {
    final db = await instance.database;
    return await db.query(
      'ticket',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'last_modified ASC',
    );
  }

  Future<int> markTicketAsSynced(String ticketID) async {
    final db = await instance.database;
    return await db.update(
      'ticket',
      {'isSynced': 1},
      where: 'ticket_id = ?',
      whereArgs: [ticketID],
    );
  }


  Future<List<Map<String, dynamic>>> getTicketsForJourney(String journeyID) async {
    final db = await instance.database;
    return await db.query(
      'ticket',
      where: 'journey_id = ?',
      whereArgs: [journeyID],
      orderBy: 'departure ASC',
    );
  }

  Future<Map<String, dynamic>?> getTicket(String ticketID) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'ticket',
      where: 'ticket_id = ?',
      whereArgs: [ticketID],
    );
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<int> updateTicketConfidence(String ticketID, double confidence) async {
    final db = await instance.database;
    return await db.update(
      'ticket',
      {'confidence_score': confidence},
      where: 'ticket_id = ?',
      whereArgs: [ticketID],
    );
  }

  Future<int> updateTicketStatus(String ticketID, String newStatus) async {
    final db = await instance.database;
    return await db.update(
      'ticket',
      {'status': newStatus},
      where: 'ticket_id = ?',
      whereArgs: [ticketID],
    );
  }

  Future<int> deleteTicket(String ticketID) async {
    final db = await instance.database;
    return await db.delete(
      'ticket',
      where: 'ticket_id = ?',
      whereArgs: [ticketID],
    );
  }

  // ==================== Connection operations ====================

  Future<String> createConnection({
    required String journeyID,
    String? fromTicketID,
    String? toTicketID,
    required String transportType,
    Duration? estimatedDuration,
    required String status, // 'suggested', 'confirmed', 'completed', 'missed'
  }) async {
    final db = await instance.database;
    final connectionID = const Uuid().v4();
    final now = _now();
    // Store duration as TEXT in format "HH:MM:SS"
    String? durationStr;
    if (estimatedDuration != null) {
      durationStr = estimatedDuration.toString().split('.').first; // e.g., "01:30:00"
    }
    await db.insert('connection', {
      'connection_id': connectionID,
      'journey_id': journeyID,
      'from_ticket_id': fromTicketID,
      'to_ticket_id': toTicketID,
      'transport_type': transportType,
      'estimated_duration': durationStr,
      'status': status,
      'last_modified': now,
      'isSynced': 0,
      
    });
    return connectionID;
  }

  Future<List<Map<String, dynamic>>> getConnectionsForJourney(String journeyID) async {
    final db = await instance.database;
    return await db.query(
      'connection',
      where: 'journey_id = ?',
      whereArgs: [journeyID],
      orderBy: 'connection_id', // or sort by related ticket times if needed
    );
  }

  Future<List<Map<String, dynamic>>> getUnsyncedConnections() async {
    final db = await instance.database;
    return await db.query(
      'connection',
      where: 'isSynced = ?',
      whereArgs: [0],
      orderBy: 'last_modified ASC',
    );
  }

  Future<int> markConnectionAsSynced(String connectionID) async {
    final db = await instance.database;
    return await db.update(
      'connection',
      {'isSynced': 1},
      where: 'connection_id = ?',
      whereArgs: [connectionID],
    );
  }
  // ==================== AI Processing Queue operations ====================

  Future<String> enqueueAITask({
    required String imageData, // base64 or local path
    String? ticketID, // may be null if ticket not yet created
  }) async {
    final db = await instance.database;
    final queueID = const Uuid().v4();
    final now = _now();
    await db.insert('ai_processing_queue', {
      'queue_id': queueID,
      'ticket_id': ticketID,
      'image_data': imageData,
      'queued_at': now,
      'processed_at': null,
      'status': 'queued',
      'result_json': null,
      'last_modified': now,   
      'isSynced': 0, 
    });
    return queueID;
  }

  Future<List<Map<String, dynamic>>> getPendingAITasks() async {
    final db = await instance.database;
    return await db.query(
      'ai_processing_queue',
      where: 'status = ?',
      whereArgs: ['queued'],
      orderBy: 'queued_at ASC',
    );
  }

  Future<int> updateAITaskResult(String queueID, {
    required String status, // 'completed' or 'failed'
    String? resultJson,
  }) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();
    return await db.update(
      'ai_processing_queue',
      {
        'status': status,
        'processed_at': now,
        'result_json': resultJson,
      },
      where: 'queue_id = ?',
      whereArgs: [queueID],
    );
  }

  // ==================== General helpers ====================

  // Close the database (useful for testing)
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}