enum PushPermission { undetermined, allowed, denied }

abstract interface class PushPlatform {
  String get devicePlatform;
  Future<void> initialize();
  Future<PushPermission> permission({bool request = false});
  Future<String?> token();
  Future<void> deleteToken();
  Future<void> subscribe(String topic);
  Future<void> unsubscribe(String topic);
  Future<Map<String, String>?> initialMessage();
  Stream<String> get tokenChanges;
  Stream<Map<String, String>> get openedMessages;
  Stream<Map<String, String>> get foregroundMessages;
}
