import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/features/directorio/data/in_memory_service_directory_repository.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/service_directory_repository.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';

/// Real directory of the signed-in account. `AuthenticatedApp` overrides it with the PowerSync
/// implementation; while it is `null` the screens use the in-memory double.
final syncedServiceDirectoryRepositoryProvider = Provider<ServiceDirectoryRepository?>(
  (ref) => null,
);

/// Directory the screens use. In practice mode nothing reaches the real repository.
final serviceDirectoryRepositoryProvider = Provider<ServiceDirectoryRepository>((ref) {
  final synced = ref.watch(syncedServiceDirectoryRepositoryProvider);
  if (synced != null) {
    final practice = ref.watch(practiceModeProvider);
    // Fail closed while preferences load: no real command may escape practice mode.
    if (!practice.hasValue) throw StateError('Cargando el modo práctica.');
    if (practice.value != true) return synced;
  }
  return ref.watch(practiceServiceDirectoryRepositoryProvider);
});

/// In-memory directory for practice mode and for building the screens without a backend.
final practiceServiceDirectoryRepositoryProvider = Provider<ServiceDirectoryRepository>((ref) {
  final session = ref.watch(effectiveSessionProvider);
  final now = DateTime.now();
  final repository = InMemoryServiceDirectoryRepository(
    currentNeighborId: session.neighborId,
    zoneId: session.zoneId,
    categories: const [
      Category(
        id: 'gasfiteria',
        name: 'Gasfitería',
        icon: 'plumbing',
        usefulInEmergency: true,
        order: 1,
      ),
      Category(
        id: 'electricidad',
        name: 'Electricidad',
        icon: 'electrical_services',
        usefulInEmergency: true,
        order: 2,
      ),
      Category(id: 'clases', name: 'Clases', icon: 'school', usefulInEmergency: false, order: 3),
    ],
    services: [
      Service(
        id: '01970000-0000-7000-8000-00000000d001',
        providerId: '01970000-0000-7000-8000-0000000000a1',
        zoneId: session.zoneId,
        categoryId: 'gasfiteria',
        title: 'Gasfitero a domicilio',
        description: 'Arreglo fugas y cambio caños.',
        location: const GeoPoint(-12.086, -77.035),
        availableInEmergency: true,
        reviewCount: 3,
        averageRating: 4.7,
        rankingScore: 4.4,
        zoneEndorsements: 2,
        version: 1,
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ],
    providers: [
      ProviderProfile(
        id: '01970000-0000-7000-8000-0000000000a1',
        publicName: 'Ana (vecina verificada)',
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
    ],
  );
  ref.onDispose(repository.close);
  return repository;
});

/// Categories of the directory.
final categoriesProvider = StreamProvider<List<Category>>((ref) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(serviceDirectoryRepositoryProvider).watchCategories();
});

/// Services of the zone that match a query, sorted like the server.
final servicesProvider = StreamProvider.family<List<Service>, ServiceQuery>((ref, query) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(serviceDirectoryRepositoryProvider).watchServices(query);
});

/// One service of the zone.
final serviceProvider = StreamProvider.family<Service?, String>((ref, serviceId) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(serviceDirectoryRepositoryProvider).watchService(serviceId);
});

/// Public profile of a provider of the zone.
final providerProfileProvider = StreamProvider.family<ProviderProfile?, String>((ref, providerId) {
  if (!_ready(ref)) return const Stream.empty();
  return ref.watch(serviceDirectoryRepositoryProvider).watchProvider(providerId);
});

/// Waits for practice-mode preferences before touching the real repository.
bool _ready(Ref ref) =>
    ref.watch(syncedServiceDirectoryRepositoryProvider) == null ||
    ref.watch(practiceModeProvider).hasValue;
