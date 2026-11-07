import 'package:vecinal/features/cuenta/domain/auth_repository.dart';

/// Verifies the phone outside the API (Firebase Authentication) and hands over an ID token
/// that the API exchanges for the usual session.
abstract interface class PhoneVerifier {
  /// Sends the SMS code to a phone in international format. If the phone gets verified without
  /// typing the code (Android reads the SMS, or needs none), [onVerified] receives the ID token.
  Future<CodeRequest> sendCode(String phone, {void Function(String token)? onVerified});

  /// Checks the code typed by the neighbor and returns the ID token of that sign-in.
  Future<String> tokenFor(String code);
}
