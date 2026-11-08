import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de configuración de avisos / notificaciones.
class PushSettingsScreen extends StatelessWidget {
  const PushSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Configurar avisos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Recibe notificaciones de publicaciones y alertas de tu zona.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              _settingTile('Avisos de tu zona', true, Icons.notifications_active),
              const SizedBox(height: 12),
              _settingTile('Nuevas publicaciones cercanas', true, Icons.note_add),
              const SizedBox(height: 12),
              _settingTile('Alertas de emergencia', false, Icons.warning_amber),
              const Spacer(),
              ProtoButton(
                text: 'Volver',
                icon: Icons.arrow_back,
                onPressed: () => Navigator.pop(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile(String title, bool value, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF0B5FAD)),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: Switch(value: value, onChanged: (_) {}),
    );
  }
}
