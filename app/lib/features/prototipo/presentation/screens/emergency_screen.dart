import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de modo emergencia — contacto con servicios de emergencia.
class EmergencyScreen extends StatelessWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Modo emergencia')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 80, color: Colors.red),
                const SizedBox(height: 24),
                const Text(
                  'Emergencia',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Si hay riesgo para la vida, llama a los servicios de emergencia:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                _emergencyButton('116', 'Bomberos', Icons.local_fire_department),
                const SizedBox(height: 12),
                _emergencyButton('105', 'Policía', Icons.local_police),
                const SizedBox(height: 12),
                _emergencyButton('106', 'Ambulancia / SAMU', Icons.medical_services),
                const SizedBox(height: 32),
                const Text(
                  'Esta app conecta vecinos; no reemplaza a los servicios de emergencia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  text: 'Volver al muro',
                  icon: Icons.arrow_back,
                  onPressed: () => Navigator.pop(context),
                  fullWidth: true,
                ),
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
    );
  }
}
