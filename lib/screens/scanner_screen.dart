import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/database_helper.dart';
import '../widgets/journey_selector_bottom_sheet.dart'; // import the shared selector

class ScannerScreen extends StatefulWidget {
  /// Optional journey ID if the ticket is being added to a specific journey.
  final String? journeyId;

  const ScannerScreen({super.key, this.journeyId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _isLoading = false;
  final _picker = ImagePicker();

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);

    try {
      final bytes = await image.readAsBytes();
      final mimeType = _getMimeType(image.path);

      // 1. Send to Gemini AI for parsing
      final ticketData = await GeminiService.parseTicket(
        imageBytes: bytes,
        mimeType: mimeType,
      );

      if (ticketData == null) {
        _showError('Could not extract ticket data. Please try again or enter manually.');
        return;
      }

      // 2. Determine which journey to associate the ticket with
      String? targetJourneyId = widget.journeyId;

      // If no journey was provided, let the user select or create one
      if (targetJourneyId == null) {
        final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();
        targetJourneyId = await showJourneySelector(context, userId);
        if (targetJourneyId == null) {
          _showMessage('Ticket not saved. No journey selected.');
          return;
        }
      }

      // 3. Prepare the ticket map for database insertion
      final ticketMap = ticketData.toMap();
      ticketMap['journey_id'] = targetJourneyId;
      ticketMap['source_type'] = source == ImageSource.camera ? 'camera' : 'gallery';
      ticketMap['image_path'] = image.path;
      ticketMap['isSynced'] = 0;
      ticketMap['last_modified'] = DateTime.now().toIso8601String();

      // 4. Save to local SQLite
      await DatabaseHelper.instance.createTicketFromMap(ticketMap);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Ticket imported successfully!')),
        );
        Navigator.pop(context); // return to timeline
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getMimeType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Travel Ticket')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.document_scanner, size: 100, color: Color(0xFF1A237E)),
                  const SizedBox(height: 40),
                  ElevatedButton.icon(
                    onPressed: () => _pickAndProcessImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Upload Screenshot (WhatsApp/Email)'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF6D00)),
                  ),
                  const SizedBox(height: 20),
                  TextButton.icon(
                    onPressed: () => _pickAndProcessImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take Photo of Paper Ticket'),
                  ),
                ],
              ),
      ),
    );
  }
}