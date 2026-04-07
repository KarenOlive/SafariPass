import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Send verification code to the given phone number.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(String, int?) onCodeSent,
    required Function(String) onCodeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout,
    );
  }

  /// Sign in with the SMS code.
  Future<UserCredential> signInWithSmsCode(String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return await _auth.signInWithCredential(credential);
  }

  /// Sign in with a PhoneAuthCredential (used for auto‑verification).
  Future<UserCredential> signInWithCredential(PhoneAuthCredential credential) async {
    return await _auth.signInWithCredential(credential);
  }

  /// Sign out the current user.
  Future<void> signOut() async => await _auth.signOut();

  /// Get the currently signed-in user.
  User? getCurrentUser() => _auth.currentUser;

  /// Listen to authentication state changes.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ------------------------------------------------------------
  // Existing custom token method (keep for legacy/local users)
  // ------------------------------------------------------------
  static Future<void> authenticateLocalUser(String localUserId, {required String registrationSecret}) async {
    final callable = FirebaseFunctions.instance.httpsCallable('createCustomTokenForLocalUser');
    final result = await callable.call(<String, dynamic>{
      'local_user_id': localUserId,
      'secret': registrationSecret,
    });
    final token = result.data['token'] as String?;
    if (token == null) {
      throw Exception('No token returned from functions');
    }
    await FirebaseAuth.instance.signInWithCustomToken(token);
  }
}