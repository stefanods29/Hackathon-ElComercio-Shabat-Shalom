import 'package:vecinal/core/storage/pending_photo_purger.dart';

/// Deletes what an account leaves on the phone, on sign-out and on account deletion.
///
/// Pending photos go first, so none is uploaded once the session closes; then the session with
/// its databases; then the files and keys that stay on disk.
Future<void> purgeAccountData(
  String accountId, {
  required PendingPhotoPurger pendingPhotos,
  required Future<void> Function() closeSession,
  required Future<void> Function(String accountId) discardStorage,
}) async {
  await pendingPhotos.purge(accountId);
  await closeSession();
  await discardStorage(accountId);
}
