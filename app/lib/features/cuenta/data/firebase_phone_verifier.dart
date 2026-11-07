import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/phone_verifier.dart';

/// Firebase sends and checks the SMS. Only the API keeps a session: the Firebase one is closed
/// as soon as its ID token is obtained.
class FirebasePhoneVerifier implements PhoneVerifier {
  FirebasePhoneVerifier({FirebaseAuth? auth}) : _authOverride = auth;

  // Firebase does not report these times; they match the API's own code (60 s and 5 min).
  static const _codeRequest = CodeRequest(retryAfterSeconds: 60, expiresInSeconds: 300);
  static const _sendLimit = Duration(minutes: 2);
  static const _sendError = 'No se pudo enviar el código. Vuelve a intentarlo.';
  static const _checkError = 'No se pudo confirmar tu número. Vuelve a intentarlo.';
  static const _wrongCode = {'invalid-verification-code', 'session-expired'};

  final FirebaseAuth? _authOverride;
  String? _phone;
  String? _verificationId;
  int? _resendToken;
  Future<String>? _automaticToken;
  Future<void> _signIns = Future.value();

  FirebaseAuth get _auth => _authOverride ?? FirebaseAuth.instance;

  @override
  Future<CodeRequest> sendCode(String phone, {void Function(String token)? onVerified}) async {
    if (phone != _phone) {
      _phone = phone;
      _verificationId = null;
      _resendToken = null;
    }
    _automaticToken = null;
    final sent = Completer<CodeRequest>();
    void fail(Object error) {
      if (!sent.isCompleted) sent.completeError(error);
    }

    try {
      await _auth.setLanguageCode('es');
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (credential) {
          unawaited(_signInAutomatically(credential, onVerified));
          if (!sent.isCompleted) sent.complete(_codeRequest);
        },
        verificationFailed: (error) => fail(_failure(error, _sendError)),
        codeSent: (verificationId, resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          if (!sent.isCompleted) sent.complete(_codeRequest);
        },
        codeAutoRetrievalTimeout: (verificationId) => _verificationId = verificationId,
      );
    } on FirebaseAuthException catch (error) {
      fail(_failure(error, _sendError));
    } on Object catch (error) {
      // Firebase did not start: missing FIREBASE_* defines or native project files.
      debugPrint('Firebase Auth no está disponible: ${error.runtimeType}');
      fail(const AuthFailure(_sendError));
    }
    return sent.future.timeout(_sendLimit, onTimeout: () => throw const AuthFailure(_sendError));
  }

  @override
  Future<String> tokenFor(String code) async {
    // Android already verified this phone: the typed code is no longer needed.
    final automatic = _automaticToken;
    if (automatic != null) return automatic;
    final verificationId = _verificationId;
    if (verificationId == null) throw const AuthFailure('Vuelve a pedir el código.');
    return _signIn(PhoneAuthProvider.credential(verificationId: verificationId, smsCode: code));
  }

  /// Android read the SMS or verified the number without one: the code is not needed.
  Future<void> _signInAutomatically(
    PhoneAuthCredential credential,
    void Function(String token)? onVerified,
  ) async {
    final token = _signIn(credential);
    _automaticToken = token;
    try {
      onVerified?.call(await token);
    } catch (_) {
      // The neighbor can still type the code from the SMS.
      if (identical(_automaticToken, token)) _automaticToken = null;
    }
  }

  /// One sign-in at a time: an automatic one may arrive while the neighbor types the code.
  Future<String> _signIn(PhoneAuthCredential credential) {
    final result = _signIns.then((_) => _idToken(credential));
    _signIns = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<String> _idToken(PhoneAuthCredential credential) async {
    try {
      final result = await _auth.signInWithCredential(credential);
      final token = await result.user?.getIdToken();
      if (token == null) throw const AuthFailure(_checkError);
      return token;
    } on FirebaseAuthException catch (error) {
      if (_wrongCode.contains(error.code)) throw const InvalidCode();
      throw _failure(error, _checkError);
    } finally {
      await _auth.signOut().catchError((Object _) {});
    }
  }

  static AuthFailure _failure(FirebaseAuthException error, String fallback) {
    // Only the code: Firebase messages may repeat the phone number.
    debugPrint('Firebase Auth: ${error.code}');
    final message = switch (error.code) {
      'invalid-phone-number' => 'Revisa el número de celular.',
      'too-many-requests' => 'Hiciste muchos intentos. Espera un momento y vuelve a intentarlo.',
      'quota-exceeded' => 'Por ahora no se pueden enviar más códigos. Prueba más tarde.',
      'network-request-failed' => 'No hay conexión. Vuelve a intentarlo cuando tengas señal.',
      _ => fallback,
    };
    return AuthFailure(message);
  }
}
