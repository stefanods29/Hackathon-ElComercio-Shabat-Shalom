import 'dart:async';

import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/directorio/domain/service_directory_repository.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart' show LocalValidationError;

/// In-memory directory with the SAME semantics as the PowerSync one.
///
/// Lot D builds its screens on it; `recordResponse` simulates the server's answer.
class InMemoryServiceDirectoryRepository implements ServiceDirectoryRepository {
  InMemoryServiceDirectoryRepository({
    required this.currentNeighborId,
    required this.zoneId,
    DateTime Function()? clock,
    Iterable<Category> categories = const [],
    Iterable<Service> services = const [],
    Iterable<ProviderProfile> providers = const [],
  }) : _clock = clock ?? DateTime.now {
    for (final category in categories) {
      _categories[category.id] = category;
    }
    for (final service in services) {
      _services[service.id] = service;
    }
    for (final provider in providers) {
      _providers[provider.id] = provider;
    }
  }

  final String currentNeighborId;
  final String zoneId;
  final DateTime Function() _clock;
  final _categories = <String, Category>{};
  final _services = <String, Service>{};
  final _providers = <String, ProviderProfile>{};
  final _submissions = <String, Submission>{};
  final _before = <String, Service?>{};
  final _changes = StreamController<void>.broadcast();

  List<Submission> get submissions => List.unmodifiable(_submissions.values);

  Stream<T> _watch<T>(T Function() read) async* {
    yield read();
    await for (final _ in _changes.stream) {
      yield read();
    }
  }

  @override
  Stream<List<Category>> watchCategories() =>
      _watch(() => _categories.values.toList()..sort((a, b) => a.order.compareTo(b.order)));

  @override
  Stream<List<Service>> watchServices([ServiceQuery query = const ServiceQuery()]) =>
      _watch(() => filterAndSortServices(_zoneServices(), query));

  @override
  Stream<Service?> watchService(String serviceId) =>
      _watch(() => _zoneServices().where((service) => service.id == serviceId).firstOrNull);

  @override
  Stream<ProviderProfile?> watchProvider(String providerId) => _watch(() => _providers[providerId]);

  @override
  Stream<List<Service>> watchProviderServices(String providerId) => _watch(
    () => filterAndSortServices(
      _zoneServices().where((service) => service.providerId == providerId),
      const ServiceQuery(),
    ),
  );

  @override
  Future<Submission> upsertProvider({required String publicName, String? description}) async {
    _providers[currentNeighborId] = ProviderProfile(
      id: currentNeighborId,
      publicName: publicName,
      description: description,
      updatedAt: _clock(),
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    return _enqueue(SubmissionKind.upsertProvider, currentNeighborId);
  }

  @override
  Future<Submission> publishService(ServiceDraft draft) async {
    final id = newLocalId();
    _services[id] = Service(
      id: id,
      providerId: currentNeighborId,
      zoneId: zoneId,
      categoryId: draft.categoryId,
      title: draft.title,
      description: draft.description,
      location: draft.publicLocation,
      coverageRadiusMeters: draft.coverageRadiusMeters,
      availableInEmergency: draft.availableInEmergency,
      version: 1,
      updatedAt: _clock(),
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    final submission = _enqueue(SubmissionKind.publishService, id);
    _before[submission.id] = null;
    return submission;
  }

  @override
  Future<Submission> updateService({
    required String serviceId,
    required int seenVersion,
    required ServiceDraft changes,
  }) async {
    final current = _ownService(serviceId);
    final submission = _enqueue(SubmissionKind.updateService, serviceId);
    _before[submission.id] = current;
    _services[serviceId] = Service(
      id: serviceId,
      providerId: current.providerId,
      zoneId: current.zoneId,
      categoryId: changes.categoryId,
      title: changes.title,
      description: changes.description,
      location: changes.publicLocation,
      coverageRadiusMeters: changes.coverageRadiusMeters,
      availableInEmergency: changes.availableInEmergency,
      attributes: current.attributes,
      reviewCount: current.reviewCount,
      averageRating: current.averageRating,
      rankingScore: current.rankingScore,
      zoneEndorsements: current.zoneEndorsements,
      version: seenVersion + 1,
      updatedAt: _clock(),
      submissionStatus: SubmissionStatus.savedOnPhone,
    );
    _notify();
    return submission;
  }

  @override
  Future<Submission> withdrawService(String serviceId) async {
    final current = _ownService(serviceId);
    final submission = _enqueue(SubmissionKind.withdrawService, serviceId);
    _before[submission.id] = current;
    _services.remove(serviceId);
    _notify();
    return submission;
  }

  /// Simulates the server's answer to a pending submission.
  void recordResponse(String submissionId, AttemptResult result) {
    final submission = _submissions[submissionId];
    if (submission == null) throw StateError('No existe el envío $submissionId.');
    final updated = submission.recordAttempt(result, _clock());
    _submissions[submissionId] = updated;
    final id = submission.resourceId;
    if (submission.kind == SubmissionKind.upsertProvider) {
      final provider = _providers[id];
      if (provider != null) {
        _providers[id] = ProviderProfile(
          id: provider.id,
          publicName: provider.publicName,
          description: provider.description,
          updatedAt: provider.updatedAt,
          submissionStatus: updated.status,
        );
      }
    } else if (updated.status == SubmissionStatus.couldNotComplete) {
      // The server decides: the optimistic change is rolled back.
      final before = _before.remove(submissionId);
      if (before == null) {
        _services.remove(id);
      } else {
        _services[id] = before.copyWith(submissionStatus: SubmissionStatus.couldNotComplete);
      }
    } else if (_services[id] case final service?) {
      _services[id] = service.copyWith(submissionStatus: updated.status);
    }
    _notify();
  }

  Future<void> close() => _changes.close();

  Iterable<Service> _zoneServices() =>
      _services.values.where((service) => service.zoneId == zoneId);

  Service _ownService(String serviceId) {
    final current = _services[serviceId];
    if (current == null) throw const LocalValidationError('Este servicio ya no está disponible.');
    if (current.providerId != currentNeighborId) {
      throw const LocalValidationError('Solo puedes cambiar tus propios servicios.');
    }
    return current;
  }

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
