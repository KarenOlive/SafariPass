import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
class AuthService {
   /// Calls the backend function to create/get a custom token for the local user id,
  /// then signs in with that token.
  static Future<void> authenticateLocalUser(String localUserId, {required String registrationSecret}) async {

    final callable = FirebaseFunctions.instance
        .httpsCallable('createCustomTokenForLocalUser');

    final result = await callable.call(<String, dynamic>{
      'local_user_id': localUserId,
      'secret': registrationSecret
    });

    final token = result.data['token'] as String?;
    if (token == null) {
      throw Exception('No token returned from functions');
    }

    await FirebaseAuth.instance.signInWithCustomToken(token);
  }
}