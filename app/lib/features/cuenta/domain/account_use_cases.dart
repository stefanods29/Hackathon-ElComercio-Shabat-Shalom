import 'package:vecinal/features/cuenta/domain/auth_repository.dart';

/// Zone change only with an empty queue (Lot A, part 4): a pending action could be lost in the
/// purge or reach the wrong zone. Lot D builds the screen on top of it.
class ChangeZone {
  const ChangeZone({required this.auth, required this.pendingUploads});

  final AuthRepository auth;

  /// Actions "Guardado en tu celular" right now, read from the local database.
  final Future<int> Function() pendingUploads;

  Future<void> call(String zoneId) async {
    final pending = await pendingUploads();
    if (pending > 0) throw PendingUploadsBlockZoneChange(pending);
    await auth.changeZone(zoneId);
  }
}

/// Account deletion: the push token goes first (at most [pushLimit], as on sign-out), then
/// [AuthRepository.deleteAccount], which only wipes the phone once the server confirms.
class DeleteAccount {
  const DeleteAccount({
    required this.auth,
    required this.unregisterPush,
    this.pushLimit = const Duration(seconds: 5),
  });

  final AuthRepository auth;
  final Future<void> Function() unregisterPush;
  final Duration pushLimit;

  Future<void> call() async {
    try {
      await unregisterPush().timeout(pushLimit);
    } catch (_) {
      // Deleting the account also deletes its devices on the server (Lot B).
    }
    await auth.deleteAccount();
  }
}
