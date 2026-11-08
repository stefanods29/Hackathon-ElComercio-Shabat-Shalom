import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';

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
      appBar: AppBar(
        title: const Text('Elige tu zona'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
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
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Esto nos muestra publicaciones y alertas de tu barrio.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              // Lista de zonas como tarjetas separadas con espaciado
              Expanded(
                child: ListView.builder(
                  itemCount: mockZones.length,
                  itemBuilder: (context, index) {
                    final zone = mockZones[index];
                    final isSelected = selectedZone?.id == zone.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _ZoneCard(
                        zone: zone,
                        isSelected: isSelected,
                        onTap: () {
                          setState(() => selectedZone = zone);
                          // Navega al muro después de elegir la zona
                          context.go('/');
                        },
                      ),
                    );
                  },
                ),
              ),
              // Botón de volver visible al final
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/'),
                  icon: const Icon(Icons.arrow_back, size: 20),
                  label: const Text(
                    'Volver',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0B5FAD),
                    side: const BorderSide(color: Color(0xFF0B5FAD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
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
      color: isSelected ? const Color(0xFF0B5FAD).withValues(alpha: 0.08) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? const Color(0xFF0B5FAD) : Colors.grey.shade300,
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
                  color: const Color(0xFF0B5FAD).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFF0B5FAD),
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      zone.district,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFF0B5FAD),
                  size: 24,
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: Colors.grey,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
