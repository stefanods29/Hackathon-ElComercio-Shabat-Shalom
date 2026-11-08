import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de cuenta (Mi cuenta) del prototipo.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Mi cuenta', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: kTextColor),
          onPressed: () => context.go('/muro'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Color(0xFFE2E8F0),
                    child: Icon(Icons.person, size: 48, color: kPrimaryColor),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Beto',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Zona: La Victoria · Lima',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ProtoButton(
                  text: 'Modo sencillo',
                  icon: Icons.accessibility,
                  onPressed: () {},
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                ProtoButton(
                  text: 'Ver tutorial',
                  icon: Icons.play_circle_outline,
                  onPressed: () => context.go('/tutorial'),
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                ProtoButton(
                  text: 'Cerrar sesión',
                  icon: Icons.logout,
                  onPressed: () => context.go('/ingresar'),
                  fullWidth: true,
                  secondary: true,
                ),
                const SizedBox(height: 32),
                const Divider(color: Color(0xFFE5E7EB)),
                const SizedBox(height: 16),
                ProtoButton(
                  text: 'Perdí mi teléfono',
                  icon: Icons.phone_disabled,
                  onPressed: () {},
                  fullWidth: true,
                  secondary: true,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
