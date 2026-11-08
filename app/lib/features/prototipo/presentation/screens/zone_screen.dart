import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

/// Pantalla para elegir la zona del vecino.
/// Cada zona se muestra como una tarjeta separada con espaciado visual.
class ZoneScreen extends StatefulWidget {
  const ZoneScreen({super.key});

  @override
  State<ZoneScreen> createState() => _ZoneScreenState();
}

class _ZoneScreenState extends State<ZoneScreen> {
  ZoneProto? selectedZone;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Elige tu zona', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Selecciona tu zona',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Esto nos muestra publicaciones y alertas de tu barrio.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: ListView.builder(
                  itemCount: mockZones.length,
                  itemBuilder: (context, index) {
                    final zone = mockZones[index];
                    final isSelected = selectedZone?.id == zone.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _ZoneCard(
                        zone: zone,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => selectedZone = zone);
                          context.go('/muro');
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
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

  const _ZoneCard({
    required this.zone,
    required this.isSelected,
    required this.onTap,
  });

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
                child: const Icon(
                  Icons.location_on,
                  color: kPrimaryColor,
                  size: 26,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      zone.name,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextColor),
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
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF), size: 24),
            ],
          ),
        ),
      ),
    );
  }
}
