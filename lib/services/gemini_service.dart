import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:safaripass/env/env.dart';

class GeminiService {
  static String get _apiKey => Env.geminiApiKey;
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// NEW: Method for the Journey Planner Chat with Grounding via REST API
  /// This ensures travel advice is up-to-date with current 2026 data.
  static Future<String?> getJourneySuggestions(String userPrompt) async {
    final url = Uri.parse('$_baseUrl/gemini-2.5-flash:generateContent?key=$_apiKey');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "systemInstruction": {
            "parts": [
              {
                "text": "You are an expert travel assistant for East Africa named SafariTravel AI. "
                        "Use Google Search to find the latest 2026 SGR schedules, bus prices (Mash, Modern Coast, etc.), "
                        "and flight details. Always provide specific prices in KES/UGX/TZS and current travel times."
              }
            ]
          },
          "contents": [
            {
              "parts": [{"text": userPrompt}]
            }
          ],
          "tools": [
            {"googleSearch": {}} // Google Search Grounding Enabled
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['candidates'][0]['content']['parts'][0]['text'];
      } else {
        print('Grounding API Error: ${response.statusCode} - ${response.body}');
        return "I couldn't fetch live data right now. Please try again.";
      }
    } catch (e) {
      print('Grounding Chat Error: $e');
      return "I'm having trouble connecting to the travel network right now.";
    }
  }

  /// Extracts travel ticket data from an image using REST API & Grounding.
  ///
  /// [imageBytes] – Raw image data.
  /// [mimeType] – MIME type of the image (e.g., 'image/jpeg', 'image/png').
  /// Returns a list of [TicketData] objects when the ticket contains multiple trips.
  static Future<List<TicketData>?> parseTicket({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final url = Uri.parse('$_baseUrl/gemini-2.5-flash:generateContent?key=$_apiKey');

    // Comprehensive system prompt with examples
    final promptText = """
You are an expert at extracting travel information from East African tickets.
Tickets can be from SGR (train), Jambojet, Safarilink, Kenya Airways, buses, or handwritten notes.

IMPORTANT: If the ticket contains multiple trip segments (e.g. Round-Trip with outbound and return, Connecting Flights, or Multiple Passengers with different legs), you MUST return a SEPARATE object for EACH segment in the JSON array.

Each object should include:
- carrier
- pnr
- departure (ISO 8601)
- arrival (ISO 8601)
- origin
- destination
- seat
- status
- confidence
Use null for missing fields.
Return ONLY the JSON array or object.

Examples:
[
  {
    "carrier": "SGR",
    "pnr": "SGR123456",
    "departure": "2026-02-15T14:00:00",
    "arrival": "2026-02-15T20:00:00",
    "origin": "Nairobi",
    "destination": "Mombasa",
    "seat": "Coach 2, Seat 12",
    "status": "confirmed",
    "confidence": 0.95
  },
  {
    "carrier": "SGR",
    "pnr": "SGR123456",
    "departure": "2026-02-16T08:00:00",
    "arrival": "2026-02-16T13:00:00",
    "origin": "Mombasa",
    "destination": "Nairobi",
    "seat": "Coach 3, Seat 06",
    "status": "confirmed",
    "confidence": 0.9
  }
]
""";

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": promptText},
                {
                  "inlineData": {
                    "mimeType": mimeType,
                    "data": base64Encode(imageBytes)
                  }
                }
              ]
            }
          ],
          "generationConfig": {
            "responseMimeType": "application/json",
            "temperature": 0.0 // keep it factual
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['candidates'][0]['content']['parts'][0]['text'];
        return _parseResponseList(textResponse);
      } else {
        debugPrint('Gemini API Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Gemini API exception: $e');
      return null;
    }
  }

  /// Extracts travel ticket data from raw OCR text using REST API.
  ///
  /// [rawText] – OCR extracted text from the image.
  /// Returns a list of [TicketData] objects when the ticket contains multiple trips.
  static Future<List<TicketData>?> parseTicketFromText(String rawText) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final promptText = """
You are an expert at extracting travel information from East African tickets based on raw OCR text.
Tickets can be from SGR (train), Jambojet, Safarilink, Kenya Airways, buses, or manually typed.
The following text is OCR-extracted from a ticket image. It may contain typos or disjointed words.

IMPORTANT: If the text describes multiple travel segments (e.g. Round-Trip with outbound and return, Connecting Flights, or Multiple Passengers with different legs), you MUST return a SEPARATE object for EACH segment in the "tickets" array.

Return ONLY a JSON object containing an array called "tickets".
Each object should include:
- carrier
- pnr
- departure (ISO 8601)
- arrival (ISO 8601)
- origin
- destination
- seat
- status
- confidence
Use null for missing fields.

Example Response:
{
  "tickets": [
    {
      "carrier": "Jambojet",
      "pnr": "ABC123",
      "departure": "2026-05-10T10:00:00",
      "arrival": "2026-05-10T11:00:00",
      "origin": "NBO",
      "destination": "MBA",
      "seat": "12A",
      "status": "confirmed",
      "confidence": 0.98
    },
    {
      "carrier": "Jambojet",
      "pnr": "ABC123",
      "departure": "2026-05-15T18:00:00",
      "arrival": "2026-05-15T19:00:00",
      "origin": "MBA",
      "destination": "NBO",
      "seat": "14C",
      "status": "confirmed",
      "confidence": 0.95
    }
  ]
}

OCR Text:
$rawText
""";

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.groqApiKey}'
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "user",
              "content": promptText
            }
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.0 
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['choices'][0]['message']['content'];
        return _parseResponseList(textResponse);
      } else {
        debugPrint('Groq Text Parsing Error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Groq Text Parsing exception: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Ticket parsing from SMS text using REST API
  // ------------------------------------------------------------------
  static Future<List<TicketData>?> parseSmsText(String smsText) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    final promptText = """
Extract travel details from this SMS ticket.
IMPORTANT: If the SMS describes multiple segments or a round trip, return a SEPARATE object for EACH segment in the "tickets" array.

Return ONLY a JSON object containing an array called "tickets".
Each object should include: carrier, pnr, departure (ISO 8601), arrival (ISO 8601), origin, destination, seat, status, confidence.
Use null for missing fields.

SMS: $smsText
""";

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${Env.groqApiKey}'
        },
        body: jsonEncode({
          "model": "llama-3.3-70b-versatile",
          "messages": [
            {
              "role": "user",
              "content": promptText
            }
          ],
          "response_format": {"type": "json_object"},
          "temperature": 0.0
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final textResponse = data['choices'][0]['message']['content'];
        return _parseResponseList(textResponse);
      } else {
        debugPrint('Groq SMS parsing error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Groq SMS parsing exception: $e');
      return null;
    }
  }

  // ------------------------------------------------------------------
  // Shared JSON parser for single ticket or list of tickets
  // ------------------------------------------------------------------
  static List<TicketData>? _parseResponseList(String jsonString) {
    try {
      final cleaned = _extractJson(jsonString);
      final decoded = jsonDecode(cleaned);

      final items = <Map<String, dynamic>>[];
      if (decoded is List) {
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            items.add(entry);
          }
        }
      } else if (decoded is Map<String, dynamic>) {
        if (decoded.containsKey('tickets') && decoded['tickets'] is List) {
          for (final entry in decoded['tickets']) {
            if (entry is Map<String, dynamic>) {
              items.add(entry);
            }
          }
        } else {
          items.add(decoded);
        }
      } else {
        throw FormatException('Unexpected JSON structure');
      }

      return items.map(_normalizeTicketData).toList();
    } catch (e) {
      debugPrint('Failed to parse Gemini JSON list: $e\nRaw: $jsonString');
      return null;
    }
  }

  static TicketData _normalizeTicketData(Map<String, dynamic> map) {
    return TicketData(
      carrier: map['carrier'] as String?,
      pnr: map['pnr'] as String?,
      departure: _toIso8601(map['departure']),
      arrival: _toIso8601(map['arrival']),
      origin: map['origin'] as String?,
      destination: map['destination'] as String?,
      seat: map['seat'] as String?,
      status: map['status'] as String?,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.5,
    );
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
    if (value is String) {
      try {
        return DateTime.parse(value).toIso8601String();
      } catch (_) {
        return value;
      }
    }
    return null;
  }

  /// Removes markdown code fences if present.
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
      'confidence_score': confidence,
    };
  }
}
