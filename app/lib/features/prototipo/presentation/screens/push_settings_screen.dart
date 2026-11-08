import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de configuración de avisos / notificaciones.
class PushSettingsScreen extends StatelessWidget {
  const PushSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Avisos', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
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
                'Configurar avisos',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Recibe notificaciones de publicaciones y alertas de tu zona.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 28),
              _settingTile('Avisos de tu zona', true, Icons.notifications_active, kPrimaryColor),
              const SizedBox(height: 14),
              _settingTile('Nuevas publicaciones cercanas', true, Icons.note_add, kPrimaryColor),
              const SizedBox(height: 14),
              _settingTile('Alertas de emergencia', false, Icons.warning_amber, kWarningColor),
              const Spacer(),
              ProtoButton(
                text: 'Volver',
                icon: Icons.arrow_back,
                onPressed: () => context.go('/mapa'),
                fullWidth: true,
                secondary: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _settingTile(String title, bool value, IconData icon, Color iconColor) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 24),
        title: Text(title, style: const TextStyle(fontSize: 15, color: kTextColor, fontWeight: FontWeight.w500)),
        trailing: Switch(
          value: value,
          onChanged: (_) {},
          activeThumbColor: kPrimaryColor,
        ),
      ),
    );
  }
}
