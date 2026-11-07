import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/config/app_environment.dart';
import 'package:vecinal/core/storage/secure_store.dart';
import 'package:vecinal/core/sync/sync_service.dart';

/// Cross-cutting providers. Each lot replaces a double with its real implementation by
/// overriding the provider; no screen changes.
final environmentProvider = Provider<AppEnvironment>((ref) => AppEnvironment.fromDefines());

/// Injectable current time: makes the "hace X" tests deterministic.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final secureStoreProvider = Provider<SecureStore>((ref) => const SystemSecureStore());

/// The neighbor's session on the phone. The real one (OTP + tokens) arrives with Lots A and B.
class LocalSession {
  const LocalSession({required this.neighborId, required this.zoneId, required this.displayName});

  /// Neighbor from the backend seed (`backend/scripts/seed-data.ts`).
  static const demo = LocalSession(
    neighborId: '01970000-0000-7000-8000-0000000000b1',
    zoneId: '01970000-0000-7000-8000-000000000001',
    displayName: 'Beto (vecino)',
  );

  final String neighborId;
  final String zoneId;
  final String displayName;
}

final sessionProvider = Provider<LocalSession>((ref) => LocalSession.demo);

/// Sync engine. A double until Lot A delivers the PowerSync implementation.
final syncServiceProvider = Provider<SyncService>((ref) {
  final service = FakeSyncService(SyncStatus(connected: true, lastSyncedAt: DateTime.now()));
  ref.onDispose(service.close);
  return service;
});

final syncStatusProvider = StreamProvider<SyncStatus>(
  (ref) => ref.watch(syncServiceProvider).watch(),
);
