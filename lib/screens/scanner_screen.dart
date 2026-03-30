import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/gemini_service.dart';
import '../services/database_helper.dart';
import '../widgets/journey_selector_bottom_sheet.dart';

class ScannerScreen extends StatefulWidget {
  final String? journeyId;

  const ScannerScreen({super.key, this.journeyId});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

// Added SingleTickerProviderStateMixin for the scanning animation
class _ScannerScreenState extends State<ScannerScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  final _picker = ImagePicker();
  
  late AnimationController _animationController;
  late Animation<double> _scanAnimation;

  @override
  void initState() {
    super.initState();
    // Setup the sweeping scan line animation
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _scanAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessImage(ImageSource source) async {
    final XFile? image = await _picker.pickImage(source: source);
    if (image == null) return;

    setState(() => _isLoading = true);
    _animationController.repeat(reverse: true); // Start the scanner animation

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

      if (targetJourneyId == null) {
        final userId = await DatabaseHelper.instance.getOrCreateDefaultUserId();
        // Stop animation while waiting for user input on the bottom sheet
        _animationController.stop(); 
        
        targetJourneyId = await showJourneySelector(context, userId);
        if (targetJourneyId == null) {
          _showMessage('Ticket not saved. No journey selected.');
          return;
        }
        _animationController.repeat(reverse: true);
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
          const SnackBar(content: Text('✅ Ticket imported successfully!'), backgroundColor: Colors.green),
        );
        // Only pop if there is a screen to pop back to (handles BottomNav vs direct navigation)
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  String _getMimeType(String path) {
    if (path.endsWith('.jpg') || path.endsWith('.jpeg')) return 'image/jpeg';
    if (path.endsWith('.png')) return 'image/png';
    return 'application/octet-stream';
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Simulated Camera Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.grey.shade900, Colors.grey.shade800, Colors.grey.shade900],
              ),
            ),
          ),

          // 2. Header Gradient & Text
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 64, bottom: 32),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: const [
                  Text('Scan Your Ticket', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('Position the ticket or screenshot within the frame', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
          ),

          // Optional Close Button (if navigated to directly rather than via BottomNav)
          if (Navigator.canPop(context))
            Positioned(
              top: 56, right: 24,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: Colors.white.withAlpha(50), shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ),
            ),

          // 3. Camera Viewfinder Frame
          Center(
            child: SizedBox(
              width: 320,
              height: 380,
              child: Stack(
                children: [
                  // 3x3 Grid
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                    itemCount: 9,
                    itemBuilder: (context, index) => Container(
                      decoration: BoxDecoration(border: Border.all(color: Colors.white.withAlpha(50), width: 0.5)),
                    ),
                  ),

                  // Corner Markers
                  _buildCornerMarker(Alignment.topLeft, const Border(top: BorderSide(color: Color(0xFFFF6D00), width: 4), left: BorderSide(color: Color(0xFFFF6D00), width: 4))),
                  _buildCornerMarker(Alignment.topRight, const Border(top: BorderSide(color: Color(0xFFFF6D00), width: 4), right: BorderSide(color: Color(0xFFFF6D00), width: 4))),
                  _buildCornerMarker(Alignment.bottomLeft, const Border(bottom: BorderSide(color: Color(0xFFFF6D00), width: 4), left: BorderSide(color: Color(0xFFFF6D00), width: 4))),
                  _buildCornerMarker(Alignment.bottomRight, const Border(bottom: BorderSide(color: Color(0xFFFF6D00), width: 4), right: BorderSide(color: Color(0xFFFF6D00), width: 4))),

                  // Animated Scanning Line (Visible when loading)
                  if (_isLoading)
                    AnimatedBuilder(
                      animation: _scanAnimation,
                      builder: (context, child) {
                        return Positioned(
                          top: _scanAnimation.value * 376, // Frame height minus line height
                          left: 0, right: 0,
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF6D00),
                              boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withAlpha(150), blurRadius: 20, spreadRadius: 2)],
                            ),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.only(top: 32, bottom: 48, left: 24, right: 24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter, end: Alignment.topCenter,
                  colors: [Colors.black87, Colors.transparent],
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Upload Gallery Button
                      GestureDetector(
                        onTap: _isLoading ? null : () => _pickAndProcessImage(ImageSource.gallery),
                        child: Column(
                          children: [
                            Container(
                              width: 64, height: 64,
                              decoration: BoxDecoration(color: Colors.white.withAlpha(50), shape: BoxShape.circle),
                              child: const Icon(Icons.upload_file, color: Colors.white, size: 28),
                            ),
                            const SizedBox(height: 8),
                            const Text('Upload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      
                      // Capture Camera Button
                      GestureDetector(
                        onTap: _isLoading ? null : () => _pickAndProcessImage(ImageSource.camera),
                        child: Column(
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6D00), 
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: const Color(0xFFFF6D00).withAlpha(128), blurRadius: 20)],
                              ),
                              child: _isLoading 
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : const Icon(Icons.camera_alt, color: Colors.white, size: 36),
                            ),
                            const SizedBox(height: 8),
                            Text(_isLoading ? 'Scanning...' : 'Capture', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      
                      // Empty placeholder to balance the row symmetrically
                      const SizedBox(width: 64), 
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Instructions Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white.withAlpha(25), borderRadius: BorderRadius.circular(16)),
                    child: const Text(
                      'Powered by Gemini AI\nAutomatically extracts ticket details from screenshots, PDFs, or photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget to draw the orange corner markers
  Widget _buildCornerMarker(Alignment alignment, Border border) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(border: border, borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}