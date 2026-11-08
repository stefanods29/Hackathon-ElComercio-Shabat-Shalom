import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';

enum EmergencyNeed { water, food, medicine, transport, shelter, other }

enum HelpRequestStatus { local, sent, seen, onTheWay, attended, referred, closedUnattended }

enum ResourceKind { water, food, medicine, shelter, meetingPoint, other }

enum ResourceVerification { unverified, neighbors, verified }

class EmergencyScope {
  const EmergencyScope({required this.accountId, required this.zoneId, required this.practice});
  final String accountId;
  final String zoneId;
  final bool practice;
  String get key => '${practice ? "practice" : "account"}:$accountId:$zoneId';
}

class RequestHistoryEntry {
  const RequestHistoryEntry({required this.status, required this.at, this.reason, this.role});
  final HelpRequestStatus status;
  final DateTime at;
  final String? reason;
  final String? role;
}

/// A private view of the current account's request; never includes helper identities.
class OwnHelpRequest {
  const OwnHelpRequest({
    required this.id,
    required this.idempotencyKey,
    required this.need,
    required this.description,
    required this.locationLabel,
    required this.approximateLocation,
    required this.createdAt,
    required this.history,
    this.sentAt,
    this.reason,
    this.nextStep,
    this.canConfirmAttendance = false,
  });
  final String id;
  final String idempotencyKey;
  final EmergencyNeed need;
  final String description;
  final String locationLabel;
  final GeoPoint approximateLocation;
  final DateTime createdAt;
  final DateTime? sentAt;
  final List<RequestHistoryEntry> history;
  final String? reason;
  final String? nextStep;
  final bool canConfirmAttendance;
  HelpRequestStatus get status => history.last.status;
  DateTime get updatedAt => history.last.at;
}

class HelpRequestDraft {
  const HelpRequestDraft({
    required this.id,
    required this.idempotencyKey,
    required this.need,
    required this.description,
    required this.locationLabel,
    required this.approximateLocation,
  });
  final String id;
  final String idempotencyKey;
  final EmergencyNeed need;
  final String description;
  final String locationLabel;
  final GeoPoint approximateLocation;
}

class HelpOffer {
  const HelpOffer({
    required this.id,
    required this.idempotencyKey,
    required this.description,
    required this.createdAt,
    this.status = SubmissionStatus.savedOnPhone,
  });
  final String id;
  final String idempotencyKey;
  final String description;
  final DateTime createdAt;
  final SubmissionStatus status;
}

class ResourceSource {
  const ResourceSource({
    required this.name,
    required this.verifiedAt,
    this.url,
    this.official = false,
  });
  final String name;
  final DateTime verifiedAt;
  final Uri? url;

  /// Only populated by a curated source/adapter, never by a neighbor's form.
  final bool official;
}

class CriticalResource {
  const CriticalResource({
    required this.id,
    required this.kind,
    required this.description,
    required this.reportedAt,
    this.staleAfter,
    this.verification = ResourceVerification.unverified,
    this.confirmations = 0,
    this.source,
    this.status = SubmissionStatus.sent,
  });
  final String id;
  final ResourceKind kind;
  final String description;
  final DateTime reportedAt;
  final Duration? staleAfter;
  final ResourceVerification verification;
  final int confirmations;
  final ResourceSource? source;
  final SubmissionStatus status;
}

class ResourceReportDraft {
  const ResourceReportDraft({
    required this.id,
    required this.idempotencyKey,
    required this.kind,
    required this.description,
    this.quantity,
    this.location,
  });
  final String id;
  final String idempotencyKey;
  final ResourceKind kind;

  /// Practice only: Lot B accepts no free text from the reporter.
  final String description;

  /// Lot B: the report carries type, quantity and an approximate point.
  final int? quantity;
  final GeoPoint? location;
}

/// Values are illustrative freshness hints, not response-time commitments.
class ResourceFreshnessPolicy {
  const ResourceFreshnessPolicy({
    this.thresholds = const {
      ResourceKind.water: Duration(hours: 2),
      ResourceKind.food: Duration(hours: 4),
      ResourceKind.medicine: Duration(hours: 2),
      ResourceKind.shelter: Duration(hours: 12),
      ResourceKind.meetingPoint: Duration(days: 30),
      ResourceKind.other: Duration(hours: 4),
    },
  });
  final Map<ResourceKind, Duration> thresholds;
  bool isStale(CriticalResource resource, DateTime now) {
    final threshold = resource.staleAfter ?? thresholds[resource.kind] ?? const Duration(hours: 2);
    return now.difference(resource.reportedAt) >= threshold;
  }
}

class EmergencySnapshot {
  const EmergencySnapshot({
    this.coverageVerified = false,
    this.activeEvent = false,
    this.updatedAt,
    this.requests = const [],
    this.offers = const [],
    this.resources = const [],
  });

  /// Set only by a trusted integration; connectivity alone is not coverage.
  final bool coverageVerified;
  final bool activeEvent;
  final DateTime? updatedAt;
  final List<OwnHelpRequest> requests;
  final List<HelpOffer> offers;
  final List<CriticalResource> resources;
}

/// Each instance is bound to one account and zone. Implementations must enforce ownership.
abstract interface class EmergencyRepository {
  Stream<EmergencySnapshot> watch();
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft);
  Future<void> confirmAttendance(String requestId);
  Future<void> saveOffer(HelpOffer offer);
  Future<void> reportResource(ResourceReportDraft draft);
}

class UnavailableEmergencyRepository implements EmergencyRepository {
  const UnavailableEmergencyRepository();
  @override
  Stream<EmergencySnapshot> watch() => Stream.value(const EmergencySnapshot());
  @override
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft) async =>
      throw StateError('Unavailable');
  @override
  Future<void> confirmAttendance(String requestId) async => throw StateError('Unavailable');
  @override
  Future<void> saveOffer(HelpOffer offer) async => throw StateError('Unavailable');
  @override
  Future<void> reportResource(ResourceReportDraft draft) async => throw StateError('Unavailable');
}
