import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/network/cdn_client.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_repository.dart';
import 'package:vecinal/features/emergencias/data/emergency_directory_store.dart';
import 'package:vecinal/features/emergencias/data/own_help_request_repository.dart';
import 'package:vecinal/features/emergencias/domain/emergency_directory.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';

/// National numbers bundled with the app, shown until the first valid download.
const emergencyBackupAsset = 'assets/emergencia/respaldo.json';

Future<String> loadEmergencyBackup() => rootBundle.loadString(emergencyBackupAsset);

/// Emergency directory. `AuthenticatedApp` replaces it with a copy on disk that it refreshes from
/// the CDN; this default only shows the bundled backup and never calls the network by itself.
final emergencyDirectoryRepositoryProvider = Provider<EmergencyDirectoryRepository>((ref) {
  final cdn = createCdnClient(ref.watch(environmentProvider));
  final repository = EmergencyDirectoryRepository(
    cdn: cdn,
    store: InMemoryEmergencyDirectoryStore(),
    loadBackup: loadEmergencyBackup,
    clock: ref.watch(clockProvider),
  );
  ref.onDispose(() {
    unawaited(repository.close());
    cdn.close(force: true);
  });
  return repository;
});

/// Thresholds of "posiblemente desactualizado" (30 days; 180 for numbers).
final emergencyStalenessPolicyProvider = Provider<EmergencyStalenessPolicy>(
  (ref) => const EmergencyStalenessPolicy(),
);

final emergencyDirectoryProvider = StreamProvider<EmergencyDirectory>(
  (ref) => ref.watch(emergencyDirectoryRepositoryProvider).watch(),
);

// Available only within the authenticated account scope.
final ownHelpRequestRepositoryProvider = Provider<OwnHelpRequestRepository?>((ref) => null);

/// The board's read-only seam for the authenticated account and zone.
final emergencyBoardRepositoryProvider = Provider<EmergencyBoardRepository?>((ref) => null);

final emergencyBoardProvider = StreamProvider.autoDispose<PublicEmergencySnapshot>(
  (ref) => ref.watch(emergencyBoardRepositoryProvider)?.watch() ?? const Stream.empty(),
);
