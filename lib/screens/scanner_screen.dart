import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/gemini_service.dart';
import '../services/database_helper.dart';
import '../models/ticket_data.dart';

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
        targetJourneyId = await _selectJourney();
        if (targetJourneyId == null) {
          // User cancelled journey selection – do not save the ticket
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

  /// Shows a dialog for the user to select an existing journey or create a new one.
  /// Returns the chosen journey ID, or null if the operation was cancelled.
  Future<String?> _selectJourney() async {
    final dbHelper = DatabaseHelper.instance;

    // Ensure we have a user (for journey creation)
    final userId = await dbHelper.getOrCreateDefaultUserId();

    // Fetch all existing journeys
    final journeys = await dbHelper.getAllJourneys(userId);

    if (journeys.isEmpty) {
      // No journeys exist – ask user to create one
      final bool? createNew = await _showConfirmationDialog(
        title: 'No Journeys Found',
        content: 'You have no journeys yet. Would you like to create one now?',
      );
      if (createNew != true) return null;
      return _createNewJourney(userId);
    }

    // Show selection dialog
    return showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select a Journey'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: journeys.length + 1, // +1 for "Create New"
              itemBuilder: (ctx, index) {
                if (index == journeys.length) {
                  // Last item: Create new journey
                  return ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Create New Journey'),
                    onTap: () {
                      Navigator.pop(context, 'CREATE_NEW');
                    },
                  );
                }
                final journey = journeys[index];
                return ListTile(
                  title: Text(journey['title'] ?? 'Unnamed Journey'),
                  subtitle: Text(
                    '${journey['start_date']} – ${journey['end_date']}',
                  ),
                  onTap: () {
                    Navigator.pop(context, journey['journey_id']);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, null),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ).then((selected) async {
      if (selected == 'CREATE_NEW') {
        return _createNewJourney(userId);
      }
      return selected; // could be null or a journey ID
    });
  }

  /// Helper to create a new journey with a default title (current date).
  Future<String> _createNewJourney(String userId) async {
    final now = DateTime.now();
    final startDate = DateTime(now.year, now.month, now.day); // today at 00:00
    final endDate = startDate.add(const Duration(days: 1)); // default 1-day trip

    String? title;
    if (mounted) {
      // Optional: ask user for a title
      title = await _showTextInputDialog(
        title: 'New Journey',
        hint: 'Enter a name (e.g., "Mombasa Trip")',
      );
    }

    final journeyId = await DatabaseHelper.instance.createJourney(
      userID: userId,
      title: title?.isEmpty ?? true ? 'Trip ${DateFormat.yMMMd().format(now)}' : title,
      startDate: startDate,
      endDate: endDate,
      status: 'upcoming',
    );
    return journeyId;
  }

  /// Simple confirmation dialog (Yes/No).
  Future<bool?> _showConfirmationDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }

  /// Simple text input dialog.
  Future<String?> _showTextInputDialog({
    required String title,
    String hint = '',
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: hint),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
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