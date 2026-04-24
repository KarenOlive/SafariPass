import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../env/env.dart';

class FlightStatusService {
  static final FlightStatusService _instance = FlightStatusService._internal();

  factory FlightStatusService() {
    return _instance;
  }

  FlightStatusService._internal();

  final String _aviationStackUrl = 'http://api.aviationstack.com/v1/flights';

  /// Map airline names to IATA codes
  static const Map<String, String> _airlineIataMap = {
    'jambojet': 'JM',
    'safarilink': 'F2',
    'kenya airways': 'KQ',
    'fly540': '5H',
    'uganda airlines': 'UR',
    'rwandair': 'WB',
    'air tanzania': 'TC',
    'jk': 'JK',
    'lh': 'LH',
    'af': 'AF',
    'ba': 'BA',
    'qf': 'QF',
    'aa': 'AA',
    'ac': 'AC',
  };

  /// Extract IATA flight code from carrier and PNR
  /// e.g., "JK 101" → "JK101" or "Kenya Airways", "KQ 200" → "KQ200"
  String? _getFlightIata(String? carrier, String? pnr) {
    if (carrier == null && pnr == null) return null;

    final full = '${carrier ?? ''} ${pnr ?? ''}'.toLowerCase().trim();

    // Try Pattern 1: "XX NNN" format (already has IATA code)
    final regexMatch = RegExp(r'([a-z]{2})\s*(\d+)').firstMatch(full);
    if (regexMatch != null) {
      return '${regexMatch.group(1)!.toUpperCase()}${regexMatch.group(2)!}';
    }

    // Try Pattern 2: Airline name lookup
    for (var entry in _airlineIataMap.entries) {
      if (full.contains(entry.key)) {
        final pnrDigits = full.replaceAll(RegExp(r'[^0-9]'), '');
        if (pnrDigits.isNotEmpty) {
          return '${entry.value}$pnrDigits';
        }
        return entry.value;
      }
    }

    return null;
  }

  /// Fetch flight status from Aviation Stack API
  /// Returns map with: status, delay, gate, arrival_time, departure_time
  Future<Map<String, dynamic>?> fetchFlightStatus({
    required String flightIata,
    required String flightDate, // Format: YYYY-MM-DD
  }) async {
    try {
      final uri = Uri.parse(_aviationStackUrl).replace(
        queryParameters: {
          'access_key': Env.aviationStackApiKey,
          'flight_iata': flightIata,
          'flight_date': flightDate,
        },
      );

      final response = await http.get(uri);

      if (response.statusCode != 200) {
        debugPrint('❌ Aviation Stack API error: ${response.statusCode}');
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>?;
      final flights = data?['data'] as List?;

      if (flights == null || flights.isEmpty) {
        debugPrint('⚠️ No flights found for $flightIata on $flightDate');
        return null;
      }

      final flightData = flights.first as Map<String, dynamic>;
      return {
        'status': flightData['flight_status'],
        'delay': flightData['arrival']?['delay'],
        'gate': flightData['departure']?['gate'],
        'arrival_time': flightData['arrival']?['estimated'] ?? flightData['arrival']?['scheduled'],
        'departure_time': flightData['departure']?['estimated'] ?? flightData['departure']?['scheduled'],
      };
    } catch (e) {
      debugPrint('❌ Error fetching flight status: $e');
      return null;
    }
  }

  /// Batch fetch status for multiple tickets
  /// Returns map of ticketId → flightStatus
  Future<Map<String, Map<String, dynamic>>> fetchFlightStatusBatch(
    List<Map<String, dynamic>> tickets,
  ) async {
    final results = <String, Map<String, dynamic>>{};

    // Filter flights only (exclude trains, buses, etc.)
    final flights = tickets.where((t) {
      final carrier = (t['carrier'] ?? '').toString().toLowerCase();
      return !carrier.contains('sgr') &&
          !carrier.contains('train') &&
          !carrier.contains('bus') &&
          !carrier.contains('coast') &&
          !carrier.contains('mash');
    }).toList();

    if (flights.isEmpty) {
      debugPrint('ℹ️ No flight tickets to check');
      return results;
    }

    debugPrint('🔍 Checking ${flights.length} flight(s)...');

    for (final ticket in flights) {
      final ticketId = ticket['ticket_id'] as String?;
      final carrier = ticket['carrier'] as String?;
      final pnr = ticket['pnr'] as String?;
      final departure = ticket['departure'] as String?;

      if (ticketId == null || departure == null) continue;

      final flightIata = _getFlightIata(carrier, pnr);
      if (flightIata == null) {
        debugPrint('⚠️ Could not extract flight code for $carrier $pnr');
        continue;
      }

      final flightDate = departure.split('T').first; // Extract YYYY-MM-DD

      debugPrint('📍 Fetching status for $flightIata on $flightDate...');
      final status = await fetchFlightStatus(
        flightIata: flightIata,
        flightDate: flightDate,
      );

      if (status != null) {
        results[ticketId] = status;
        debugPrint('✅ Got status for $flightIata: ${status['status']}');
      }

      // Rate limiting: avoid hitting API too fast
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return results;
  }
}
