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

const _practiceListings = [
  (
    category: 'carpinteria',
    title: 'Reparación de muebles',
    name: 'Leandro Níspero',
    description: 'Reparo sillas y muebles de madera.',
    location: GeoPoint(-12.081, -77.042),
    rating: 4.6,
    reviews: 5,
    endorsements: 3,
    emergency: false,
  ),
  (
    category: 'carpinteria',
    title: 'Ajuste de puertas de madera',
    name: 'Elvira Canelo',
    description: 'Ajusto bisagras y puertas que se traban.',
    location: GeoPoint(-12.075, -77.038),
    rating: 4.4,
    reviews: 7,
    endorsements: 1,
    emergency: true,
  ),
  (
    category: 'cerrajeria',
    title: 'Apertura de puertas',
    name: 'Noé Arrayán',
    description: 'Ayudo cuando una cerradura se atasca.',
    location: GeoPoint(-12.083, -77.029),
    rating: 4.9,
    reviews: 12,
    endorsements: 5,
    emergency: true,
  ),
  (
    category: 'cerrajeria',
    title: 'Cambio de cerraduras',
    name: 'Renata Cornejo',
    description: 'Cambio cerraduras y reviso pestillos.',
    location: GeoPoint(-12.093, -77.044),
    rating: 4.5,
    reviews: 4,
    endorsements: 2,
    emergency: true,
  ),
  (
    category: 'costura',
    title: 'Arreglos de ropa',
    name: 'Amalia Totoral',
    description: 'Ajusto prendas y cambio cierres.',
    location: GeoPoint(-12.087, -77.048),
    rating: 4.8,
    reviews: 16,
    endorsements: 4,
    emergency: false,
  ),
  (
    category: 'mayores',
    title: 'Acompañamiento a mayores',
    name: 'Ciro Aguaymanto',
    description: 'Acompaño en paseos y trámites cercanos.',
    location: GeoPoint(-12.077, -77.025),
    rating: 4.7,
    reviews: 8,
    endorsements: 3,
    emergency: false,
  ),
  (
    category: 'mascotas',
    title: 'Paseo de perros',
    name: 'Paloma Quenual',
    description: 'Hago paseos cortos por el barrio.',
    location: GeoPoint(-12.071, -77.031),
    rating: 4.3,
    reviews: 3,
    endorsements: 1,
    emergency: false,
  ),
  (
    category: 'mascotas',
    title: 'Cuidado de gatos',
    name: 'Nélida Amancaes',
    description: 'Visito a gatos para darles comida y compañía.',
    location: GeoPoint(-12.091, -77.036),
    rating: 4.9,
    reviews: 6,
    endorsements: 2,
    emergency: false,
  ),
  (
    category: 'delivery-mercado',
    title: 'Compras del mercado a domicilio',
    name: 'Darío Huarango',
    description: 'Recojo compras y las llevo a casa.',
    location: GeoPoint(-12.084, -77.056),
    rating: 4.6,
    reviews: 9,
    endorsements: 4,
    emergency: true,
  ),
];

/// In-memory directory for practice mode and for building the screens without a backend.
final practiceServiceDirectoryRepositoryProvider = Provider<ServiceDirectoryRepository>((ref) {
  final session = ref.watch(effectiveSessionProvider);
  final now = DateTime.now();
  final listings = _practiceListings.indexed;
  String providerId(int index) => '01970000-0000-7000-8000-000000000a2${index + 1}';
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
      Category(
        id: 'carpinteria',
        name: 'Carpintería',
        icon: 'carpenter',
        usefulInEmergency: true,
        order: 4,
      ),
      Category(
        id: 'cerrajeria',
        name: 'Cerrajería',
        icon: 'key',
        usefulInEmergency: true,
        order: 5,
      ),
      Category(
        id: 'costura',
        name: 'Costura',
        icon: 'content_cut',
        usefulInEmergency: false,
        order: 6,
      ),
      Category(
        id: 'mayores',
        name: 'Cuidado de mayores',
        icon: 'elderly',
        usefulInEmergency: false,
        order: 7,
      ),
      Category(id: 'mascotas', name: 'Mascotas', icon: 'pets', usefulInEmergency: false, order: 8),
      Category(
        id: 'delivery-mercado',
        name: 'Delivery de mercado',
        icon: 'local_shipping',
        usefulInEmergency: true,
        order: 9,
      ),
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
      for (final (index, listing) in listings)
        Service(
          id: '01970000-0000-7000-8000-000000000d2${index + 1}',
          providerId: providerId(index),
          zoneId: session.zoneId,
          categoryId: listing.category,
          title: listing.title,
          description: listing.description,
          location: listing.location,
          availableInEmergency: listing.emergency,
          reviewCount: listing.reviews,
          averageRating: listing.rating,
          rankingScore: listing.rating,
          zoneEndorsements: listing.endorsements,
          version: 1,
          updatedAt: now.subtract(Duration(days: index + 1)),
        ),
    ],
    providers: [
      ProviderProfile(
        id: '01970000-0000-7000-8000-0000000000a1',
        publicName: 'Ana (vecina verificada)',
        description: 'Ofrezco arreglos de gasfitería en el barrio.',
        updatedAt: now.subtract(const Duration(days: 2)),
      ),
      for (final (index, listing) in listings)
        ProviderProfile(
          id: providerId(index),
          publicName: listing.name,
          description: listing.description,
          updatedAt: now.subtract(Duration(days: 30 * (index + 1))),
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
