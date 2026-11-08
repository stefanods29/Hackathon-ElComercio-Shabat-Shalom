import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ChooseZonePage extends ConsumerStatefulWidget {
  const ChooseZonePage({super.key});
  @override
  ConsumerState<ChooseZonePage> createState() => _ChooseZonePageState();
}

class _ChooseZonePageState extends ConsumerState<ChooseZonePage> {
  late Future<List<Zone>> _zonesFuture;
  bool _isChoosing = false;

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  void _loadZones() {
    _zonesFuture = ref.read(authRepositoryProvider).listZones();
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final tokens = context.vecinalTokens;
    return Scaffold(
      appBar: AppBar(title: Text(texts.chooseZoneTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Padding(
              padding: EdgeInsets.all(tokens.spaceXl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texts.chooseZoneSubtitle, style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: tokens.spaceSm),
                  Text(texts.chooseZoneDetail, style: Theme.of(context).textTheme.bodyLarge),
                  SizedBox(height: tokens.spaceXl),
                  Expanded(
                    child: FutureBuilder<List<Zone>>(
                      future: _zonesFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        if (snapshot.hasError) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.cloud_off_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                                SizedBox(height: tokens.spaceMd),
                                Text(texts.authTryAgainError, textAlign: TextAlign.center),
                                SizedBox(height: tokens.spaceMd),
                                OutlinedButton.icon(
                                  onPressed: () => setState(_loadZones),
                                  icon: const Icon(Icons.refresh),
                                  label: Text(texts.retryAction),
                                ),
                              ],
                            ),
                          );
                        }
                        final zones = snapshot.data ?? const <Zone>[];
                        if (zones.isEmpty) return Center(child: Text(texts.noZonesAvailable));
                        return ListView.separated(
                          itemCount: zones.length,
                          separatorBuilder: (_, _) => SizedBox(height: tokens.spaceSm),
                          itemBuilder: (context, index) {
                            final zone = zones[index];
                            return Card.outlined(
                              child: ListTile(
                                minTileHeight: 68,
                                leading: Icon(
                                  Icons.location_on_outlined,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                title: Text(
                                  zone.name,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                subtitle: Text(zone.district),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: _isChoosing ? null : () => _choose(zone.id),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _choose(String zoneId) async {
    setState(() => _isChoosing = true);
    try {
      await ref.read(authRepositoryProvider).chooseZone(zoneId);
      if (mounted) context.go(Routes.home);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isChoosing = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).chooseZoneError)));
    }
  }
}
