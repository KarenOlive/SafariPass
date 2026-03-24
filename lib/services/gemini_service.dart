import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:safaripass/env/env.dart';

class GeminiService {
   static String get _apiKey => Env.geminiApiKey;

  /// Extracts travel ticket data from an image.
  /// 
  /// [imageBytes] – Raw image data.
  /// [mimeType] – MIME type of the image (e.g., 'image/jpeg', 'image/png').
  /// Returns a [TicketData] object if successful, otherwise null.
  static Future<TicketData?> parseTicket({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final model = GenerativeModel(
      model: 'gemini-2.5-flash', // or 'gemini-1.5-flash'
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.0, // keep it factual
      ),
    );

    // Comprehensive system prompt with examples
    final prompt = TextPart("""
You are an expert at extracting travel information from East African tickets.
Tickets can be from SGR (train), Jambojet, Safarilink, Kenya Airways, buses, or handwritten notes.
Extract as many of the following fields as possible from the image:

- carrier: e.g., "SGR", "Jambojet", "Safarilink", "Kenya Airways", "Modern Coast"
- pnr: booking reference (e.g., "SGR123456", "JB98765", "KQ123")
- departure: full date and time in ISO 8601 format (e.g., "2026-02-15T14:00:00")
- arrival: ISO 8601 timestamp if available (e.g., "2026-02-15T19:30:00")
- origin: departure city or airport code (e.g., "Nairobi", "NBO")
- destination: arrival city or airport code (e.g., "Mombasa", "MBA")
- seat: seat number, coach, or compartment (e.g., "12A", "Coach 5")
- status: ticket status if mentioned (e.g., "confirmed", "boarding", "delayed")
- confidence: your confidence in the extraction (0.0–1.0)

Return ONLY a JSON object with these keys. Use null for missing fields.

Examples:
SGR SMS: "Ticket No: SGR123456, Train: 5, Date: 15/02/2026, Time: 14:00, Coach: 2, Seat: 12"
→ {
  "carrier": "SGR",
  "pnr": "SGR123456",
  "departure": "2026-02-15T14:00:00",
  "arrival": null,
  "origin": "Nairobi",
  "destination": "Mombasa",
  "seat": "Coach 2, Seat 12",
  "status": "confirmed",
  "confidence": 0.95
}

Jambojet WhatsApp: "Booking Ref: JB98765, Flight: JM 123, Date: 15 FEB 2026, Time: 13:00, Gate: 12"
→ {
  "carrier": "Jambojet",
  "pnr": "JB98765",
  "departure": "2026-02-15T13:00:00",
  "arrival": null,
  "origin": "Nairobi",
  "destination": "Mombasa",
  "seat": null,
  "status": "confirmed",
  "confidence": 0.9
}

Handwritten: "Nairobi - Mombasa 2000KSh"
→ {
  "carrier": null,
  "pnr": null,
  "departure": null,
  "arrival": null,
  "origin": "Nairobi",
  "destination": "Mombasa",
  "seat": null,
  "status": null,
  "confidence": 0.6
}
""");

    final imagePart = DataPart(mimeType, imageBytes);

    try {
      final response = await model.generateContent([
        Content.multi([prompt, imagePart])
      ]);

      if (response.text == null) {
        print('Gemini returned empty response');
        return null;
      }

      return _parseResponse(response.text!);
    } catch (e) {
      print('Gemini API error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Ticket parsing from SMS text
  // ------------------------------------------------------------------
  static Future<TicketData?> parseSmsText(String smsText) async {
    final model = GenerativeModel(
      model: 'gemini-2.0-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
        temperature: 0.0,
      ),
    );

    final prompt = TextPart("""
Extract travel details from this SMS ticket. Return ONLY a JSON object with these keys:
carrier, pnr, departure (ISO 8601), arrival (ISO 8601), origin, destination, seat, status, confidence.
Use null for missing fields.

SMS: $smsText
""");

    try {
      final response = await model.generateContent([Content.multi([prompt])]);
      if (response.text == null) return null;
      return _parseResponse(response.text!);
    } catch (e) {
      print('Gemini SMS parsing error: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Shared JSON parser
  // ------------------------------------------------------------------
  static TicketData? _parseResponse(String jsonString) {
    try {
      // Gemini may wrap JSON in markdown code blocks; clean it
      final cleaned = _extractJson(jsonString);
      final Map<String, dynamic> map = jsonDecode(cleaned);

      // Convert date strings to ISO 8601 if they aren't already
      final departure = _toIso8601(map['departure']);
      final arrival = _toIso8601(map['arrival']);

      return TicketData(
        carrier: map['carrier'] as String?,
        pnr: map['pnr'] as String?,
        departure: departure,
        arrival: arrival,
        origin: map['origin'] as String?,
        destination: map['destination'] as String?,
        seat: map['seat'] as String?,
        status: map['status'] as String?,
        confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
      );
    } catch (e) {
      print('Failed to parse Gemini JSON: $e\nRaw: $jsonString');
      return null;
    }
  }

  /// Removes markdown code fences if present.
  static String _extractJson(String text) {
    final regex = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```');
    final match = regex.firstMatch(text);
    if (match != null) return match.group(1)!;
    return text;
  }

  /// Converts various date formats to ISO 8601.
  static String? _toIso8601(dynamic value) {
    if (value == null) return null;
    // If it's already an ISO string, return as-is
    if (value is String) {
      // Try parsing with DateTime to validate
      try {
        return DateTime.parse(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }
    return null;
  }
}

/// Data class matching our ticket table fields.
class TicketData {
  final String? carrier;
  final String? pnr;
  final String? departure;
  final String? arrival;
  final String? origin;
  final String? destination;
  final String? seat;
  final String? status;
  final double confidence;

  TicketData({
    this.carrier,
    this.pnr,
    this.departure,
    this.arrival,
    this.origin,
    this.destination,
    this.seat,
    this.status,
    required this.confidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'carrier': carrier,
      'pnr': pnr,
      'departure': departure,
      'arrival': arrival,
      'origin': origin,
      'destination': destination,
      'seat': seat,
      'status': status ?? 'confirmed',
    };
  }
}