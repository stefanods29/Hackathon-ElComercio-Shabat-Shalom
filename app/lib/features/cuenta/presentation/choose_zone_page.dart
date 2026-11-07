import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla para elegir la zona antes de ver el muro (/elegir-zona).
class ChooseZonePage extends ConsumerStatefulWidget {
  const ChooseZonePage({super.key});

  @override
  ConsumerState<ChooseZonePage> createState() => _ChooseZonePageState();
}

class _ChooseZonePageState extends ConsumerState<ChooseZonePage> {
  bool _isChoosing = false;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(texts.chooseZoneTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texts.chooseZoneSubtitle, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(texts.chooseZoneDetail, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            Expanded(
              child: FutureBuilder<List<Zone>>(
                future: ref.read(authRepositoryProvider).listZones(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final zones = snapshot.data ?? const [];
                  if (zones.isEmpty) {
                    return Center(child: Text(texts.noZonesAvailable));
                  }
                  return ListView.builder(
                    itemCount: zones.length,
                    itemBuilder: (context, index) {
                      final zone = zones[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: _isChoosing ? null : () => _choose(zone.id),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                              side: BorderSide.none,
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    zone.name,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  zone.district,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  Future<void> _choose(String zoneId) async {
    setState(() => _isChoosing = true);
    try {
      await ref.read(authRepositoryProvider).chooseZone(zoneId);
      if (!mounted) return;
      context.go(Routes.home);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isChoosing = false);
      final errorTexts = AppLocalizations.of(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(errorTexts.chooseZoneError)));
    }
  }
}
