import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/connection_banner.dart';
import 'package:vecinal/core/ui/image_policy.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/domain/search.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// A public, approximate reference for distances, never the device's precise location.
final directoryOriginProvider = Provider<GeoPoint>((ref) {
  final bounds = ref.watch(environmentProvider).mapBounds;
  return GeoPoint(bounds.centerLatitude, bounds.centerLongitude).approximate();
});

final providerServicesProvider = StreamProvider.family<List<Service>, String>((ref, id) {
  // Keep the same fail-closed practice boundary as A1's providers.
  if (ref.watch(syncedServiceDirectoryRepositoryProvider) != null &&
      !ref.watch(practiceModeProvider).hasValue) {
    return const Stream.empty();
  }
  return ref.watch(serviceDirectoryRepositoryProvider).watchProviderServices(id);
});

class DirectoryPage extends ConsumerStatefulWidget {
  const DirectoryPage({super.key, this.emergencyOnly = false});
  final bool emergencyOnly;
  @override
  ConsumerState<DirectoryPage> createState() => _DirectoryPageState();
}

class _DirectoryPageState extends ConsumerState<DirectoryPage> {
  String _text = '';
  String? _category;
  late bool _emergencyOnly;

  @override
  void initState() {
    super.initState();
    _emergencyOnly = widget.emergencyOnly;
    if (widget.emergencyOnly)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(imagesEnabledProvider.notifier).set(false);
      });
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final emergency = ref.watch(emergencyHomeProvider);
    final query = ServiceQuery(
      text: _text,
      categoryId: _category,
      emergencyOnly: _emergencyOnly || emergency,
    );
    final services = ref.watch(servicesProvider(query));
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final synced = ref.watch(syncStatusProvider).value?.lastSyncedAt;
    return Scaffold(
      appBar: AppBar(title: Text(t.directoryTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const ConnectionBanner(),
            TextField(
              decoration: InputDecoration(
                labelText: t.searchServices,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _text = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
                    icon: Icon(
                      _category == category.id
                          ? Icons.check_circle_outline
                          : _categoryIcon(category.icon),
                    ),
                    label: Text(category.name),
                    onPressed: () =>
                        setState(() => _category = _category == category.id ? null : category.id),
                  ),
              ],
            ),
            if (_category != null)
              TextButton(
                onPressed: () => setState(() => _category = null),
                child: Text(t.clearFilters),
              ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.usefulInEmergency),
              value: _emergencyOnly || emergency,
              onChanged: emergency ? null : (value) => setState(() => _emergencyOnly = value),
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(t.emergencyImages),
              subtitle: Text(t.emergencyImagesHelp),
              value: ref.watch(imagesEnabledProvider),
              onChanged: (value) => ref.read(imagesEnabledProvider.notifier).set(value),
            ),
            if (synced != null) Text(t.updatedAgo(timeAgo(synced, ref.watch(clockProvider)(), t))),
            if (ref.watch(syncStatusProvider).value?.connected != true)
              Text(t.emergencyOfflineWarning),
            services.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(t.directoryUnavailable),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty) Text(t.directoryEmpty),
                  if (items.isNotEmpty)
                    OutlinedButton.icon(
                      icon: const Icon(Icons.map_outlined),
                      label: Text(t.mapTitle),
                      onPressed: () => context.push(
                        Routes.map,
                        extra: MapFocus(
                          items
                              .map(
                                (s) =>
                                    MapMarker(label: s.title, location: s.location.approximate()),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  for (final service in items) ServiceTile(service: service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String name) => switch (name) {
    'plumbing' => Icons.plumbing,
    'electrical_services' => Icons.electrical_services,
    'school' => Icons.school,
    _ => Icons.handyman_outlined,
  };
}

class ServiceTile extends ConsumerWidget {
  const ServiceTile({super.key, required this.service});
  final Service service;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(service.title, style: Theme.of(context).textTheme.titleLarge),
            Text(
              t.approximateDistance(
                approximateDistanceMeters(ref.watch(directoryOriginProvider), service.location),
              ),
            ),
            Text(t.serviceRating(service.averageRating.toStringAsFixed(1), service.reviewCount)),
            Text(t.zoneEndorsements(service.zoneEndorsements)),
            SubmissionStatusChip(status: service.submissionStatus),
            FilledButton(
              onPressed: () => context.push('/servicios/${service.id}'),
              child: Text(t.viewService),
            ),
          ],
        ),
      ),
    );
  }
}
