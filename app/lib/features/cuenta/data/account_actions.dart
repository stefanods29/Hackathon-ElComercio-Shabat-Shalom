import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/features/avisos/data/providers.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/account_use_cases.dart';

/// Zone change with an empty queue (Lot A, part 4).
final changeZoneProvider = Provider<ChangeZone>(
  (ref) => ChangeZone(
    auth: ref.watch(authRepositoryProvider),
    pendingUploads: () => ref.read(syncServiceProvider).pendingUploads(),
  ),
);

/// Account deletion: push unregistration first (at most 5 s), then `DELETE /v1/yo`.
final deleteAccountProvider = Provider<DeleteAccount>(
  (ref) => DeleteAccount(
    auth: ref.watch(authRepositoryProvider),
    unregisterPush: () => ref.read(pushControllerProvider.notifier).signOut(),
  ),
);
