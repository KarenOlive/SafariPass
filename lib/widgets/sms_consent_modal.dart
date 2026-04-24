import 'package:flutter/material.dart';

class SMSConsentModal extends StatelessWidget {
  final String from;
  final String message;
  final VoidCallback onAllow;
  final VoidCallback onDeny;

  const SMSConsentModal({
    super.key,
    required this.from,
    required this.message,
    required this.onAllow,
    required this.onDeny,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Wrap content height
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFF1A2151),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.message, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Import Ticket from SMS',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF1A2151)),
                  ),
                  Text(
                    'SafariPass detected a ticket',
                    style: TextStyle(fontSize: 14, color: Color(0xFF455A64)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // SMS Preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('FROM: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF455A64))),
                    Text(from, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A2151))),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF455A64), height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Icon(Icons.info_outline, color: Color(0xFF1A2151), size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'SafariTravel will automatically import ticket details from this message. Your SMS data stays private and is processed locally.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF1A2151), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  onPressed: onDeny,
                  child: const Text('Not Now', style: TextStyle(color: Color(0xFF455A64), fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 4,
                  ),
                  onPressed: onAllow,
                  child: const Text('Import Ticket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16), // Bottom safe area padding
        ],
      ),
    );
  }
}