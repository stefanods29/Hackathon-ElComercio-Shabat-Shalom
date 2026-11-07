abstract interface class PushRegistration {
  /// False means safely queued on the phone for a later retry.
  Future<bool> register(String token, String platform);
  Future<bool> unregister(String token);
  Future<bool> retry();
}

/// Lot A supplies an authenticated snapshot. The demonstration session never registers devices.
class PushCredentials {
  const PushCredentials({required this.userId, required this.zoneId, required this.accessToken});
  final String userId;
  final String? zoneId;
  final String accessToken;
}
