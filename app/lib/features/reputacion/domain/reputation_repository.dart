import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';

/// Port of reviews, Visto Bueno and reports. Reads come only from the local database.
abstract interface class ReputationRepository {
  /// Published reviews of a service of the zone, newest first, with their photos.
  Stream<List<Review>> watchPublishedReviews(String serviceId);

  /// All my reviews, in any state, including those still on the phone.
  Stream<List<Review>> watchMyReviews();

  /// The Visto Bueno I gave, including those still on the phone.
  Stream<List<Endorsement>> watchMyEndorsements();

  /// Saves my review on the phone right away and queues it; it starts "en revisión".
  Future<Submission> writeReview(NewReview review);

  /// Queues my Visto Bueno for a service of the zone.
  Future<Submission> giveEndorsement(String serviceId);

  /// Queues the withdrawal of my Visto Bueno.
  Future<Submission> withdrawEndorsement(String serviceId);

  /// Queues a report for the moderators.
  Future<Submission> report(NewReport report);
}
