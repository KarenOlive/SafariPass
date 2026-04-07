import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/database_helper.dart';
import 'name_input_screen.dart';
import 'main_layout.dart';

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
        // Auto‑verification (e.g., SIM card detection)
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
      onCodeAutoRetrievalTimeout: (String verificationId) {
        // Optional: handle timeout
      },
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
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In with Phone')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_isCodeSent) ...[
              TextField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone number (+254...)',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                child: const Text('Send Code'),
              ),
            ] else ...[
              TextField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: '6-digit code',
                  prefixIcon: Icon(Icons.sms),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _verifyCode,
                child: const Text('Verify & Sign In'),
              ),
            ],
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}