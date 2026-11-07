abstract interface class PushRegistration {
  /// False means safely queued on the phone for a later retry.
  Future<bool> register(String token, String platform);
  Future<bool> unregister(String token);
  Future<bool> retry();
}

/// Lot A supplies the signed-in neighbor. The demonstration session never registers devices.
class PushCredentials {
  const PushCredentials({required this.userId, required this.zoneId, required this.accessToken});
  final String userId;
  final String? zoneId;

  /// Returns a current JWT of this same neighbor, renewing it if needed; null without a session.
  final Future<String?> Function() accessToken;
}
