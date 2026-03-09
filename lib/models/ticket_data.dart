class TicketData {
  final String? carrier;
  final String? pnr;
  final String? departure; // ISO 8601 string
  final String? arrival;   // ISO 8601 string
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

  /// Convert to map for database insertion (without journey_id and sync fields)
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
      // confidence is not stored in DB but can be used
    };
  }

  /// Factory constructor from JSON (if needed)
  factory TicketData.fromJson(Map<String, dynamic> json) {
    return TicketData(
      carrier: json['carrier'],
      pnr: json['pnr'],
      departure: json['departure'],
      arrival: json['arrival'],
      origin: json['origin'],
      destination: json['destination'],
      seat: json['seat'],
      status: json['status'],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}