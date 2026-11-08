/// Deletes from the phone the review photos that were never uploaded (Lot A, part 4).
///
/// Sign-out and account deletion call it before purging the account database, so a pending photo
/// is never uploaded afterwards. Lot C (part 2) implements it over its photo queue.
abstract interface class PendingPhotoPurger {
  Future<void> purge(String accountId);
}

/// Until Lot C delivers the photo queue there is nothing to delete.
class NoPendingPhotos implements PendingPhotoPurger {
  const NoPendingPhotos();

  @override
  Future<void> purge(String accountId) async {}
}
