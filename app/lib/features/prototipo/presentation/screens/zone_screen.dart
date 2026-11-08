import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  ZoneProto? _selectedZone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.chooseZoneTitle),
        leading: IconButton(
          tooltip: l10n.protoBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(ProtoRoutes.welcome),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(l10n.chooseZoneSubtitle, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(l10n.chooseZoneDetail),
            const SizedBox(height: 20),
            for (final zone in mockZones)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ZoneCard(
                  zone: zone,
                  isSelected: _selectedZone?.id == zone.id,
                  onTap: () => setState(() => _selectedZone = zone),
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: ProtoButton(
            key: const ValueKey<String>('zone-continue'),
            text: l10n.confirm,
            icon: Icons.arrow_forward,
            onPressed: _selectedZone == null ? null : () => context.go(ProtoRoutes.home()),
            fullWidth: true,
          ),
        ),
      ),
    );
  }
}

/// Tarjeta individual de zona con estado de selección accesible.
class _ZoneCard extends StatelessWidget {
  final ZoneProto zone;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoneCard({required this.zone, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      child: Card(
        color: isSelected ? kPrimaryColor.withValues(alpha: 0.06) : kSurfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusCard),
          side: BorderSide(color: isSelected ? kPrimaryColor : Colors.transparent, width: 1.5),
        ),
        child: InkWell(
          key: ValueKey<String>('zone-${zone.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(kRadiusCard),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(kRadiusLarge),
                  ),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.location_on_outlined, color: kPrimaryColor),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(zone.name, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(zone.district, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.chevron_right,
                  color: isSelected ? kPrimaryColor : kTextSecondaryColor,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
