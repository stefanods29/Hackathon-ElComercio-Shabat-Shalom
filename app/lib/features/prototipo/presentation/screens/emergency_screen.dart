import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de modo emergencia — contacto con servicios de emergencia.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Modo emergencia', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: kErrorColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.error_outline, size: 40, color: kErrorColor),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Emergencia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 16),
                Text(
                  'Si hay riesgo para la vida, llama a los servicios de emergencia:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                _emergencyButton('116', 'Bomberos', Icons.local_fire_department),
                const SizedBox(height: 14),
                _emergencyButton('105', 'Policía', Icons.local_police),
                const SizedBox(height: 14),
                _emergencyButton('106', 'Ambulancia / SAMU', Icons.medical_services),
                const SizedBox(height: 32),
                Text(
                  'Esta app conecta vecinos; no reemplaza a los servicios de emergencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 28),
                ProtoButton(
                  text: 'Volver al muro',
                  icon: Icons.arrow_back,
                  onPressed: () => context.go('/mapa'),
                  fullWidth: true,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emergencyButton(String number, String label, IconData icon) {
    return ProtoButton(
      text: '$number · $label',
      icon: icon,
      onPressed: () {},
      fullWidth: true,
      secondary: true,
    );
  }
}
