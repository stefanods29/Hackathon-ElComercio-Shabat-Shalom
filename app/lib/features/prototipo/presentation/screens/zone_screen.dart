import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
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
          padding: const EdgeInsets.all(20),
          children: [
            Text(l10n.chooseZoneTitle, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(l10n.chooseZoneDetail),
            const SizedBox(height: 24),
            for (final zone in mockZones)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _ZoneCard(
                  zone: zone,
                  isSelected: _selectedZone?.id == zone.id,
                  onTap: () {
                    setState(() => _selectedZone = zone);
                    context.go(ProtoRoutes.home());
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta individual de zona con diseño visual separado.
class _ZoneCard extends StatelessWidget {
  final ZoneProto zone;
  final bool isSelected;
  final VoidCallback onTap;

  const _ZoneCard({required this.zone, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: isSelected ? 4 : 2,
      color: isSelected ? kPrimaryColor.withValues(alpha: 0.08) : kSurfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? kPrimaryColor : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: kPrimaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.location_on, color: kPrimaryColor, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: kTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zone.district,
                      style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle, color: kPrimaryColor, size: 24)
              else
                const Icon(Icons.chevron_right, color: kTextSecondaryColor, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
