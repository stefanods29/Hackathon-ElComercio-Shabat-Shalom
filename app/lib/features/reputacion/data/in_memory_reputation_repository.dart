import 'dart:async';

import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/reputation_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// In-memory reviews, Visto Bueno and reports with the SAME semantics as the PowerSync ones.
///
/// [ownServiceIds] are the services of the current neighbor (nobody reviews themselves);
/// `recordResponse` simulates the server's answer.
class InMemoryReputationRepository implements ReputationRepository {
  InMemoryReputationRepository({
    DateTime Function()? clock,
    Iterable<Review> publishedReviews = const [],
    Iterable<Review> myReviews = const [],
    Iterable<String> endorsedServiceIds = const [],
    this._ownServiceIds = const {},
  }) : _clock = clock ?? DateTime.now {
    _published.addAll(publishedReviews);
    for (final review in myReviews) {
      _mine[review.id] = review;
    }
    for (final serviceId in endorsedServiceIds) {
      _endorsements[serviceId] = Endorsement(serviceId: serviceId);
    }
  }

  final DateTime Function() _clock;
  final Set<String> _ownServiceIds;
  final _published = <Review>[];
  final _mine = <String, Review>{};
  final _endorsements = <String, Endorsement>{};
  final _submissions = <String, Submission>{};
  final _endorsedBefore = <String, Endorsement?>{};
  final _changes = StreamController<void>.broadcast();

  List<Submission> get submissions => List.unmodifiable(_submissions.values);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<Review>> watchPublishedReviews(String serviceId) => _watch(
    () =>
        _published.where((review) => review.serviceId == serviceId).toList()
          ..sort((a, b) => (b.publishedAt ?? DateTime(0)).compareTo(a.publishedAt ?? DateTime(0))),
  );

  @override
  Stream<List<Review>> watchMyReviews() => _watch(
    () =>
        _mine.values.toList()
          ..sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0))),
  );

  @override
  Stream<List<Endorsement>> watchMyEndorsements() => _watch(() => _endorsements.values.toList());

  @override
  Future<Submission> writeReview(NewReview review) async {
    if (_ownServiceIds.contains(review.serviceId)) {
      throw const LocalValidationError('No puedes reseñar tu propio servicio.');
    }
    if (_mine.values.any((mine) => mine.serviceId == review.serviceId)) {
      throw const LocalValidationError('Ya reseñaste este servicio.');
    }
    final id = newLocalId();
    _mine[id] = Review(
      id: id,
      serviceId: review.serviceId,
      rating: review.rating,
      comment: review.comment,
      status: ReviewStatus.inReview,
      createdAt: _clock(),
      isMine: true,
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    return _enqueue(SubmissionKind.writeReview, id);
  }

  @override
  Future<Submission> giveEndorsement(String serviceId) async {
    if (_ownServiceIds.contains(serviceId)) {
      throw const LocalValidationError('No puedes dar Visto Bueno a tu propio servicio.');
    }
    if (_endorsements.containsKey(serviceId)) {
      throw const LocalValidationError('Ya diste tu Visto Bueno a este servicio.');
    }
    final submission = _enqueue(SubmissionKind.giveEndorsement, serviceId);
    _endorsedBefore[submission.id] = null;
    _endorsements[serviceId] = Endorsement(
      serviceId: serviceId,
      createdAt: _clock(),
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    _notify();
    return submission;
  }

  @override
  Future<Submission> withdrawEndorsement(String serviceId) async {
    final current = _endorsements[serviceId];
    if (current == null) {
      throw const LocalValidationError('No diste tu Visto Bueno a este servicio.');
    }
    final submission = _enqueue(SubmissionKind.withdrawEndorsement, serviceId);
    _endorsedBefore[submission.id] = current;
    _endorsements.remove(serviceId);
    _notify();
    return submission;
  }

  @override
  Future<Submission> report(NewReport report) async =>
      _enqueue(SubmissionKind.report, newLocalId());

  /// Simulates the server's answer to a pending submission.
  void recordResponse(String submissionId, AttemptResult result) {
    final submission = _submissions[submissionId];
    if (submission == null) throw StateError('No existe el envío $submissionId.');
    final updated = submission.recordAttempt(result, _clock());
    _submissions[submissionId] = updated;
    final rejected = updated.status == SubmissionStatus.couldNotComplete;
    switch (submission.kind) {
      case SubmissionKind.writeReview:
        final review = _mine[submission.resourceId];
        if (review != null && rejected) {
          _mine.remove(submission.resourceId);
        } else if (review != null) {
          _mine[review.id] = Review(
            id: review.id,
            serviceId: review.serviceId,
            rating: review.rating,
            comment: review.comment,
            status: review.status,
            createdAt: review.createdAt,
            isMine: true,
            submissionStatus: updated.status,
          );
        }
      case SubmissionKind.giveEndorsement || SubmissionKind.withdrawEndorsement:
        final serviceId = submission.resourceId;
        if (rejected) {
          final before = _endorsedBefore.remove(submissionId);
          if (before == null) {
            _endorsements.remove(serviceId);
          } else {
            _endorsements[serviceId] = before;
          }
        } else if (_endorsements[serviceId] case final endorsement?) {
          _endorsements[serviceId] = Endorsement(
            serviceId: serviceId,
            createdAt: endorsement.createdAt,
            submissionStatus: updated.status,
          );
        }
      default:
        break;
    }
    _notify();
  }

  Future<void> close() => _changes.close();

  Submission _enqueue(SubmissionKind kind, String resourceId) {
    final submission = Submission(
      id: newLocalId(),
      kind: kind,
      resourceId: resourceId,
      idempotencyKey: newLocalId(),
      createdAt: _clock(),
    );
    _submissions[submission.id] = submission;
    _notify();
    return submission;
  }

  void _notify() {
    if (!_changes.isClosed) _changes.add(null);
  }
}
