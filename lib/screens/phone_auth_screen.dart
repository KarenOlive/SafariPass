import 'dart:ui'; import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'name_input_screen.dart';
import 'main_layout.dart';

// SafariPass Palette Constants
const Color _deepCharcoal = Color(0xFF1A2151);
const Color _savannahGold = Color(0xFFF27121);

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final AuthService _auth = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  String? _verificationId;
  bool _isLoading = false;
  bool _isCodeSent = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _sendCode() async {
    if (_phoneController.text.trim().isEmpty) {
      _showError('Please enter a phone number');
      return;
    }
    setState(() => _isLoading = true);
    await _auth.verifyPhoneNumber(
      phoneNumber: _phoneController.text.trim(),
      onVerificationCompleted: (PhoneAuthCredential credential) async {
        final userCred = await _auth.signInWithCredential(credential);
        await _handleSignIn(userCred.user);
      },
      onVerificationFailed: (FirebaseAuthException e) {
        setState(() => _isLoading = false);
        _showError('Verification failed: ${e.message}');
      },
      onCodeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _isCodeSent = true;
          _isLoading = false;
        });
      },
      onCodeAutoRetrievalTimeout: (String verificationId) {},
    );
  }

  void _verifyCode() async {
    if (_verificationId == null) return;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      _showError('Please enter the 6-digit code');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final userCred = await _auth.signInWithSmsCode(_verificationId!, code);
      await _handleSignIn(userCred.user);
    } catch (e) {
      _showError('Invalid code: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSignIn(User? user) async {
    if (user == null) return;
    // Store/update user in local SQLite (phone number only)
    await DatabaseHelper.instance.createOrUpdateFirebaseUser(
      userId: user.uid,
      phoneNumber: user.phoneNumber,
    );
    // Check if the user has a name
    final userRecord = await DatabaseHelper.instance.getUser(user.uid);
    print('User saved: ${userRecord}');
    
    if (userRecord == null || (userRecord['name'] ?? '').isEmpty) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NameInputScreen()),
        );
      }
    } else {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainLayout()),
        );
      }
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  InputDecoration _customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: Colors.grey.shade600),
      prefixIcon: Icon(icon, color: _savannahGold),
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _savannahGold, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _deepCharcoal,
      body: SafeArea(
        child: Column(
          children: [
            // Top Section
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(LucideIcons.planeTakeoff, color: Colors.white, size: 48),
                    ),
                    const SizedBox(height: 24),
                    const Text('SafariTravel', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('Your journey, simplified', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 16)),
                  ],
                ),
              ),
            ),
            
            // White Bottom Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(32),
                  topRight: Radius.circular(32),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isCodeSent ? 'Verify Number' : 'Welcome!',
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _deepCharcoal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isCodeSent 
                        ? 'Enter the 6-digit code sent to your phone.' 
                        : 'Enter your phone number to get started',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 32),
                  if (!_isCodeSent) ...[
                    TextField(
                      controller: _phoneController,
                      style: const TextStyle(color: _deepCharcoal),
                      decoration: _customInputDecoration('Phone Number', LucideIcons.phone),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _savannahGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _sendCode,
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ] else ...[
                    TextField(
                      controller: _codeController,
                      style: const TextStyle(color: _deepCharcoal),
                      decoration: _customInputDecoration('6-digit code', LucideIcons.messageSquare),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _savannahGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isLoading ? null : _verifyCode,
                        child: _isLoading
                            ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Text('Verify & Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}