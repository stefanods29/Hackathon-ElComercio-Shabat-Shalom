import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/cuenta/presentation/profile_page.dart';
import 'package:vecinal/features/directorio/data/providers.dart';
import 'package:vecinal/features/directorio/domain/directory.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/demo_profiles.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/presentation/report_button.dart';
import 'package:vecinal/features/reputacion/presentation/reviews_section.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// C3 may inject the public profile link once its canonical host is deployed.
final profileShareLinkProvider = Provider<Uri? Function(String)>(
  (ref) =>
      (_) => null,
);

class ServiceDetailPage extends ConsumerWidget {
  const ServiceDetailPage({super.key, required this.serviceId});
  final String serviceId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.viewService)),
      body: SafeArea(
        child: ref
            .watch(serviceProvider(serviceId))
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(child: Text(t.serviceUnavailable)),
              data: (service) => service == null
                  ? Center(child: Text(t.serviceUnavailable))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        Card(
                          margin: EdgeInsets.zero,
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  service.title,
                                  style: Theme.of(context).textTheme.headlineSmall,
                                ),
                                if (service.description != null) ...[
                                  const SizedBox(height: 8),
                                  Text(service.description!),
                                ],
                                const SizedBox(height: 12),
                                SubmissionStatusChip(status: service.submissionStatus),
                                const SizedBox(height: 16),
                                _DetailFact(
                                  icon: Icons.star_rounded,
                                  color: AccessibleTheme.ratingColor(Theme.of(context).colorScheme),
                                  text: t.serviceRating(
                                    service.averageRating.toStringAsFixed(1),
                                    service.reviewCount,
                                  ),
                                ),
                                _DetailFact(
                                  icon: Icons.thumb_up_alt_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                  text: t.zoneEndorsements(service.zoneEndorsements),
                                ),
                                _DetailFact(
                                  icon: Icons.place_outlined,
                                  color: Theme.of(context).colorScheme.secondary,
                                  text: t.publicApproximateLocation,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () => context.push('/proveedores/${service.providerId}'),
                          icon: const Icon(Icons.person_outline),
                          label: Text(t.viewProvider),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            Routes.map,
                            extra: MapFocus([
                              MapMarker(
                                label: service.title,
                                location: service.location.approximate(),
                              ),
                            ]),
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: Text(t.openOnMap),
                        ),
                        const SizedBox(height: 8),
                        ReportButton(content: ReportedContent.service, contentId: service.id),
                        const SizedBox(height: 8),
                        ReviewsSection(
                          serviceId: service.id,
                          isOwnService:
                              service.providerId == ref.watch(effectiveSessionProvider).neighborId,
                        ),
                        if (service.providerId ==
                            ref.watch(effectiveSessionProvider).neighborId) ...[
                          OutlinedButton(
                            onPressed: () => context.push('/servicios/${service.id}/editar'),
                            child: Text(t.editService),
                          ),
                          TextButton(
                            onPressed: () => _withdraw(context, ref, service),
                            child: Text(t.withdrawService),
                          ),
                        ],
                      ],
                    ),
            ),
      ),
    );
  }

  Future<void> _withdraw(BuildContext context, WidgetRef ref, Service service) async {
    final t = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.withdrawService),
        content: Text(t.withdrawServiceBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(t.confirm)),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(serviceDirectoryRepositoryProvider).withdrawService(service.id);
      if (context.mounted) {
        context.go(Routes.directory);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.statusSavedOnPhone)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.actionFailed)));
      }
    }
  }
}

class ProviderProfilePage extends ConsumerWidget {
  const ProviderProfilePage({super.key, required this.providerId});
  final String providerId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final services = ref.watch(providerServicesProvider(providerId));
    final theme = Theme.of(context);
    final profile = ref.watch(providerProfileProvider(providerId));
    return Scaffold(
      appBar: wrappingAppBar(context, t.providerTitle),
      body: SafeArea(
        child: profile.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(child: Text(t.providerUnavailable)),
          data: (provider) => provider == null
              ? Center(child: Text(t.providerUnavailable))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: spaced([
                    Row(
                      spacing: 16,
                      children: [
                        ProfileAvatar(name: provider.publicName),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 4,
                            children: [
                              Text(provider.publicName, style: theme.textTheme.headlineSmall),
                              if (provider.description case final description?) Text(description),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SubmissionStatusChip(status: provider.submissionStatus),
                    Text(
                      t.providerNeighborSince(
                        DateFormat.yMMMM(t.localeName).format(provider.updatedAt.toLocal()),
                      ),
                    ),
                    services.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (_, _) => Text(t.serviceUnavailable),
                      data: (items) => Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _DetailFact(
                            icon: Icons.storefront_outlined,
                            color: theme.colorScheme.primary,
                            text: t.providerServiceCount(items.length),
                          ),
                          _DetailFact(
                            icon: Icons.star_rounded,
                            color: AccessibleTheme.ratingColor(theme.colorScheme),
                            text: t.serviceRating(
                              _rating(items).toStringAsFixed(1),
                              items.fold(0, (n, s) => n + s.reviewCount),
                            ),
                          ),
                          _DetailFact(
                            icon: Icons.thumb_up_alt_outlined,
                            color: theme.colorScheme.primary,
                            text: t.zoneEndorsements(
                              items.fold(0, (n, s) => n + s.zoneEndorsements),
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        try {
                          await ref
                              .read(appShareProvider)
                              .text(
                                [
                                  provider.publicName,
                                  ...services.value?.map((s) => s.title) ?? const <String>[],
                                  if (ref.read(profileShareLinkProvider)(provider.id)
                                      case final link?)
                                    link.toString(),
                                ].join('\n'),
                                shareOrigin(context),
                              );
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(t.actionFailed)));
                          }
                        }
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(t.shareAction),
                    ),
                    ReportButton(content: ReportedContent.provider, contentId: provider.id),
                    for (final service in services.value ?? const <Service>[])
                      ServiceTile(service: service),
                  ], gap: 12),
                ),
        ),
      ),
    );
  }

  double _rating(List<Service> items) {
    final count = items.fold(0, (n, s) => n + s.reviewCount);
    return count == 0 ? 0 : items.fold(0.0, (n, s) => n + s.averageRating * s.reviewCount) / count;
  }
}

class _DetailFact extends StatelessWidget {
  const _DetailFact({required this.icon, required this.color, required this.text});
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Padding(padding: const EdgeInsets.only(top: 5), child: Text(text)),
        ),
      ],
    ),
  );
}
