import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
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
    if (widget.emergencyOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(imagesEnabledProvider.notifier).set(false);
      });
    }
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
      appBar: AppBar(title: Text(t.directoryTitle, maxLines: 2, overflow: TextOverflow.clip)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const ConnectionBanner(),
            TextField(
              decoration: InputDecoration(
                hintText: t.searchServices,
                labelText: t.searchServices,
                floatingLabelBehavior: FloatingLabelBehavior.never,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _text = value),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.emergency_outlined, size: 18),
                    showCheckmark: false,
                    label: Text(t.usefulInEmergency),
                    selected: _emergencyOnly || emergency,
                    onSelected: emergency
                        ? null
                        : (value) => setState(() => _emergencyOnly = value),
                  ),
                  for (final category in categories) ...[
                    const SizedBox(width: 8),
                    FilterChip(
                      avatar: Icon(categoryIcon(category.icon), size: 18),
                      showCheckmark: false,
                      label: Text(category.name),
                      selected: _category == category.id,
                      onSelected: (_) =>
                          setState(() => _category = _category == category.id ? null : category.id),
                    ),
                  ],
                ],
              ),
            ),
            if (_category != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _category = null),
                  child: Text(t.clearFilters),
                ),
              ),
            const SizedBox(height: 8),
            if (ref.watch(syncStatusProvider).value?.connected != true)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(t.emergencyOfflineWarning),
              ),
            services.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Text(t.directoryUnavailable),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (items.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Text(t.directoryEmpty, textAlign: TextAlign.center),
                    ),
                  if (items.isNotEmpty)
                    Row(
                      children: [
                        Expanded(
                          child: synced == null
                              ? const SizedBox.shrink()
                              : Text(
                                  t.updatedAgo(timeAgo(synced, ref.watch(clockProvider)(), t)),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.map_outlined),
                          label: Text(t.mapTitle),
                          onPressed: () => context.push(
                            Routes.map,
                            extra: MapFocus(
                              items
                                  .map(
                                    (s) => MapMarker(
                                      label: s.title,
                                      location: s.location.approximate(),
                                    ),
                                  )
                                  .toList(),
                            ),
                          ),
                        ),
                      ],
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
}

IconData categoryIcon(String name) => switch (name) {
  'plumbing' => Icons.plumbing,
  'electrical_services' => Icons.electrical_services,
  'school' => Icons.school,
  'carpenter' => Icons.carpenter_outlined,
  'key' => Icons.key_outlined,
  'content_cut' => Icons.content_cut,
  'elderly' => Icons.elderly,
  'pets' => Icons.pets,
  'local_shipping' => Icons.local_shipping_outlined,
  _ => Icons.handyman_outlined,
};

class ServiceTile extends ConsumerWidget {
  const ServiceTile({super.key, required this.service});
  final Service service;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final category = ref
        .watch(categoriesProvider)
        .value
        ?.where((category) => category.id == service.categoryId)
        .firstOrNull;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/servicios/${service.id}'),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? theme.colorScheme.surfaceContainerHigh
                        : theme.colorScheme.primaryContainer,
                    foregroundColor: theme.brightness == Brightness.dark
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onPrimaryContainer,
                    child: Icon(
                      service.availableInEmergency
                          ? Icons.handyman_outlined
                          : Icons.storefront_outlined,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(service.title, style: theme.textTheme.titleLarge),
                            if (category != null) _CategoryLabel(category: category),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          t.approximateDistance(
                            approximateDistanceMeters(
                              ref.watch(directoryOriginProvider),
                              service.location,
                            ),
                          ),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _Fact(
                    icon: Icons.star_rounded,
                    color: AccessibleTheme.ratingColor(theme.colorScheme),
                    text: t.serviceRating(
                      service.averageRating.toStringAsFixed(1),
                      service.reviewCount,
                    ),
                  ),
                  _Fact(
                    icon: Icons.thumb_up_alt_outlined,
                    color: theme.colorScheme.primary,
                    text: t.zoneEndorsements(service.zoneEndorsements),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SubmissionStatusChip(status: service.submissionStatus),
                    TextButton(
                      onPressed: () => context.push('/servicios/${service.id}'),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(child: Text(t.viewService)),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 18),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryLabel extends StatelessWidget {
  const _CategoryLabel({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: ShapeDecoration(color: scheme.secondaryContainer, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Icon(categoryIcon(category.icon), size: 16, color: scheme.onSecondaryContainer),
            Flexible(
              child: Text(
                category.name,
                style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: color),
      const SizedBox(width: 6),
      Flexible(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
    ],
  );
}
