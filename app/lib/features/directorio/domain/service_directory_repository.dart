import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';

/// Port of the services directory (Repository pattern + single source of truth).
///
/// The screens only read from the local database; the network only updates it. Lot A provides
/// the PowerSync implementation and an in-memory double for Lot D's screens and the tests.
abstract interface class ServiceDirectoryRepository {
  /// Categories in their display order.
  Stream<List<Category>> watchCategories();

  /// Services of the neighbor's zone that match [query], sorted like the server.
  Stream<List<Service>> watchServices([ServiceQuery query = const ServiceQuery()]);

  /// One service of the zone, or `null` if it is not on the phone (withdrawn or hidden).
  Stream<Service?> watchService(String serviceId);

  /// Public profile of a provider of the zone, or `null` if it is not on the phone.
  Stream<ProviderProfile?> watchProvider(String providerId);

  /// Services of one provider of the zone.
  Stream<List<Service>> watchProviderServices(String providerId);

  /// Saves my provider profile on the phone and queues it.
  Future<Submission> upsertProvider({required String publicName, String? description});

  /// Saves a new service on the phone right away and queues it.
  Future<Submission> publishService(ServiceDraft draft);

  /// Queues the changes of one of my services with the version I was looking at.
  Future<Submission> updateService({
    required String serviceId,
    required int seenVersion,
    required ServiceDraft changes,
  });

  /// Queues the withdrawal of one of my services; it disappears from my lists right away.
  Future<Submission> withdrawService(String serviceId);
}
