import 'package:flutter/material.dart';
import '../widgets/sms_consent_modal.dart';

class SmsPromptButton extends StatefulWidget {
  final VoidCallback onImport;
  const SmsPromptButton({super.key, required this.onImport});

  @override
  State<SmsPromptButton> createState() => _SmsPromptButtonState();
}

class _SmsPromptButtonState extends State<SmsPromptButton> {
  void _showConsentModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SMSConsentModal(
        from: 'MADARAKA EXPRESS',
        message: 'Ticket Confirmed: NRB-MSA. PNR: 2K9J6L. Date: 12/03/2026. Seat: Coach 4, 12A. Total: KES 1,500.',
        onDeny: () => Navigator.pop(context),
        onAllow: () {
          Navigator.pop(context);
          widget.onImport();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showConsentModal(context),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2151), Color(0xFF2A3477)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A2151).withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'New SGR Ticket Detected',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      letterSpacing: -0.3,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tap to import from SMS',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white, size: 28),
          ],
        ),
      ),
    );
  }
}