import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';

/// Firebase sends and checks the SMS code in the browser (invisible reCAPTCHA). Only the API keeps
/// a session: the Firebase one is closed as soon as its ID token is obtained, and `main.dart`
/// turns Firebase persistence off so nothing stays in IndexedDB or localStorage.
class FirebaseWebVerifier {
  FirebaseWebVerifier({FirebaseAuth? auth}) : _authOverride = auth;

  // Firebase does not report these times; they match the API's own code (60 s and 5 min).
  static const _codeRequest = CodeRequest(retryAfterSeconds: 60, expiresInSeconds: 300);
  static const _wrongCode = {'invalid-verification-code', 'session-expired', 'code-expired'};

  final FirebaseAuth? _authOverride;
  ConfirmationResult? _confirmation;

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  Future<CodeRequest> sendCode(String phone) async {
    try {
      await _auth.setLanguageCode('es');
      _confirmation = await _auth.signInWithPhoneNumber(phone);
      return _codeRequest;
    } on FirebaseAuthException catch (error) {
      throw _failure(error, SignInProblem.sendFailed);
    } on Object catch (error) {
      // Firebase did not start: missing FIREBASE_* defines.
      debugPrint('Firebase Auth no está disponible: ${error.runtimeType}');
      throw const SignInFailure(SignInProblem.sendFailed);
    }
  }

  /// Checks the typed code and returns the ID token the API exchanges for its session.
  Future<String> tokenFor(String code) async {
    final confirmation = _confirmation;
    if (confirmation == null) throw const SignInFailure(SignInProblem.checkFailed);
    try {
      final result = await confirmation.confirm(code);
      final token = await result.user?.getIdToken();
      if (token == null) throw const SignInFailure(SignInProblem.checkFailed);
      _confirmation = null;
      return token;
    } on FirebaseAuthException catch (error) {
      if (_wrongCode.contains(error.code)) throw const SignInFailure(SignInProblem.invalidCode);
      throw _failure(error, SignInProblem.checkFailed);
    } finally {
      await _auth.signOut().catchError((Object _) {});
    }
  }

  static SignInFailure _failure(FirebaseAuthException error, SignInProblem fallback) {
    // Only the code: Firebase messages may repeat the phone number.
    debugPrint('Firebase Auth: ${error.code}');
    return SignInFailure(switch (error.code) {
      'invalid-phone-number' => SignInProblem.invalidPhone,
      'too-many-requests' => SignInProblem.tooManyAttempts,
      'quota-exceeded' => SignInProblem.quotaExceeded,
      'network-request-failed' => SignInProblem.network,
      _ => fallback,
    });
  }
}
