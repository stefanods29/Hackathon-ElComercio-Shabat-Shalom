import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla para elegir la zona del vecino.
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
      appBar: AppBar(title: const Text('Elige tu zona')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Selecciona tu zona',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Esto nos muestra publicaciones y alertas de tu barrio.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView.builder(
                  itemCount: mockZones.length,
                  itemBuilder: (context, index) {
                    final zone = mockZones[index];
                    return ProtoButton(
                      text: '${zone.name} · ${zone.district}',
                      icon: Icons.location_on,
                      onPressed: () {
                        setState(() => selectedZone = zone);
                        context.go('/');
                      },
                      fullWidth: true,
                      secondary: true,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
