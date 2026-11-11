import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/mode/app_mode.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';

final emergencyScopeProvider = Provider<EmergencyScope?>((ref) {
  final preference = ref.watch(practiceModeProvider);
  if (preference.isLoading || preference.hasError || !preference.hasValue) return null;
  if (preference.value == true) {
    final session = ref.watch(effectiveSessionProvider);
    return EmergencyScope(accountId: session.neighborId, zoneId: session.zoneId, practice: true);
  }
  final authentication = ref.watch(authStateProvider);
  if (authentication.isLoading || authentication.hasError) return null;
  final auth = authentication.value;
  if (auth is! SignedIn || auth.user.zoneId == null) return null;
  return EmergencyScope(
    accountId: auth.user.neighborId,
    zoneId: auth.user.zoneId!,
    practice: false,
  );
});

/// Integration seam for A/B. The real account remains unavailable until explicitly injected.
final operationalEmergencyFactoryProvider = Provider<EmergencyRepository Function(EmergencyScope)?>(
  (ref) => null,
);
final emergencyRepositoryProvider = Provider<EmergencyRepository>((ref) {
  final scope = ref.watch(emergencyScopeProvider);
  if (scope == null) return const UnavailableEmergencyRepository();
  if (!scope.practice) {
    return ref.watch(operationalEmergencyFactoryProvider)?.call(scope) ??
        const UnavailableEmergencyRepository();
  }
  final repository = PracticeEmergencyRepository(ref.watch(clockProvider));
  ref.onDispose(repository.close);
  return repository;
});
// A new repository gets a fresh asynchronous state, without the prior account's value.
final _emergencySnapshotStreamProvider = StreamProvider.autoDispose
    .family<EmergencySnapshot, EmergencyRepository>((ref, repository) => repository.watch());
final emergencySnapshotProvider = Provider<AsyncValue<EmergencySnapshot>>(
  (ref) => ref.watch(_emergencySnapshotStreamProvider(ref.watch(emergencyRepositoryProvider))),
);
final emergencyHomeProvider = Provider<bool>(
  (ref) =>
      ref.watch(appModeProvider) == AppMode.emergency ||
      ref.watch(emergencySnapshotProvider).value?.activeEvent == true,
);
final resourceFreshnessPolicyProvider = Provider<ResourceFreshnessPolicy>(
  (ref) => const ResourceFreshnessPolicy(),
);

/// In-memory practice only. No timer, upload, retry or server acknowledgment is simulated.
/// The sample places read like a real neighborhood; the "Práctica" chip marks them as examples.
class PracticeEmergencyRepository implements EmergencyRepository {
  PracticeEmergencyRepository(this.now) {
    _resources.addAll([
      CriticalResource(
        id: 'practice-water',
        kind: ResourceKind.water,
        description: 'Local comunal',
        reportedAt: now().subtract(const Duration(hours: 3)),
      ),
      CriticalResource(
        id: 'practice-food',
        kind: ResourceKind.food,
        description: 'Parroquia del barrio',
        reportedAt: now().subtract(const Duration(minutes: 20)),
        verification: ResourceVerification.neighbors,
        confirmations: 2,
      ),
      CriticalResource(
        id: 'practice-shelter',
        kind: ResourceKind.shelter,
        description: 'Colegio de la zona',
        reportedAt: now(),
        verification: ResourceVerification.verified,
        source: ResourceSource(
          name: 'Municipalidad (datos de ejemplo)',
          verifiedAt: now(),
          official: true,
        ),
      ),
    ]);
  }
  final DateTime Function() now;
  final _changes = StreamController<void>.broadcast();
  final _requests = <OwnHelpRequest>[];
  final _offers = <HelpOffer>[];
  final _resources = <CriticalResource>[];
  bool _closed = false;
  bool _eventActive = false;
  EmergencySnapshot get _snapshot => EmergencySnapshot(
    coverageVerified: true,
    activeEvent: _eventActive,
    updatedAt: now(),
    requests: List.unmodifiable(_requests),
    offers: List.unmodifiable(_offers),
    resources: List.unmodifiable(_resources),
  );
  void _ensureOpen() {
    if (_closed) throw StateError('Closed');
  }

  void _emit() {
    _ensureOpen();
    _changes.add(null);
  }

  @override
  Stream<EmergencySnapshot> watch() async* {
    yield _snapshot;
    await for (final _ in _changes.stream) {
      yield _snapshot;
    }
  }

  @override
  Future<OwnHelpRequest> saveRequest(HelpRequestDraft draft) async {
    _ensureOpen();
    final existing = _requests
        .where((r) => r.id == draft.id || r.idempotencyKey == draft.idempotencyKey)
        .firstOrNull;
    if (existing != null) return existing;
    final at = now();
    final request = OwnHelpRequest(
      id: draft.id,
      idempotencyKey: draft.idempotencyKey,
      need: draft.need,
      description: draft.description,
      locationLabel: draft.locationLabel,
      approximateLocation: draft.approximateLocation.approximate(),
      createdAt: at,
      history: [RequestHistoryEntry(status: HelpRequestStatus.local, at: at)],
    );
    _requests.insert(0, request);
    _emit();
    return request;
  }

  /// Demo simulation, practice only: the neighbor confirms a request that the simulated
  /// coordination put on the way. Nothing reaches a real coordinator.
  @override
  Future<void> confirmAttendance(String requestId) async {
    _ensureOpen();
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0 || !_requests[index].canConfirmAttendance) {
      throw StateError('No server capability in practice');
    }
    _requests[index] = _withStatus(_requests[index], HelpRequestStatus.attended, role: null);
    _emit();
  }

  /// Practice only: a simulated emergency event in the zone.
  bool get simulatedEvent => _eventActive;

  void simulateEvent({required bool active}) {
    _ensureOpen();
    _eventActive = active;
    _emit();
  }

  /// Practice only: the next step a coordinator would take (sent, seen, on the way). It is shown
  /// as simulated and never claims that a real person received the request.
  void simulateNextStep(String requestId) {
    _ensureOpen();
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (index < 0) return;
    final next = switch (_requests[index].status) {
      HelpRequestStatus.local => HelpRequestStatus.sent,
      HelpRequestStatus.sent => HelpRequestStatus.seen,
      HelpRequestStatus.seen => HelpRequestStatus.onTheWay,
      _ => null,
    };
    if (next == null) return;
    _requests[index] = _withStatus(
      _requests[index],
      next,
      role: next == HelpRequestStatus.sent ? null : simulatedRole,
    );
    _emit();
  }

  /// Practice only: a fictitious resource reported now, unverified.
  void simulateResource() {
    _ensureOpen();
    _resources.insert(
      0,
      CriticalResource(
        id: 'practice-simulated-${now().microsecondsSinceEpoch}',
        kind: ResourceKind.water,
        description: 'Pileta del parque (simulado)',
        reportedAt: now(),
      ),
    );
    _emit();
  }

  static const simulatedRole = 'coordinación simulada';

  OwnHelpRequest _withStatus(OwnHelpRequest r, HelpRequestStatus status, {required String? role}) {
    final at = now();
    return OwnHelpRequest(
      id: r.id,
      idempotencyKey: r.idempotencyKey,
      need: r.need,
      description: r.description,
      locationLabel: r.locationLabel,
      approximateLocation: r.approximateLocation,
      createdAt: r.createdAt,
      sentAt: status == HelpRequestStatus.sent ? at : r.sentAt,
      history: [
        ...r.history,
        RequestHistoryEntry(status: status, at: at, role: role),
      ],
      reason: r.reason,
      nextStep: r.nextStep,
      canConfirmAttendance: status == HelpRequestStatus.onTheWay,
    );
  }

  @override
  Future<void> saveOffer(HelpOffer offer) async {
    _ensureOpen();
    if (_offers.any((o) => o.id == offer.id || o.idempotencyKey == offer.idempotencyKey)) return;
    _offers.insert(
      0,
      HelpOffer(
        id: offer.id,
        idempotencyKey: offer.idempotencyKey,
        description: offer.description,
        createdAt: now(),
      ),
    );
    _emit();
  }

  @override
  Future<void> reportResource(ResourceReportDraft draft) async {
    _ensureOpen();
    if (_resources.any((r) => r.id == draft.id)) return;
    _resources.insert(
      0,
      CriticalResource(
        id: draft.id,
        kind: draft.kind,
        description: draft.description,
        reportedAt: now(),
        status: SubmissionStatus.savedOnPhone,
      ),
    );
    _emit();
  }

  void close() {
    _closed = true;
    _requests.clear();
    _offers.clear();
    _resources.clear();
    unawaited(_changes.close());
  }
}
