import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de cuenta (Mi cuenta) del prototipo.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const CircleAvatar(radius: 40, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 16),
              const Text(
                'Beto',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              const Text(
                'Zona: La Victoria · Lima',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
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
                onPressed: () {},
                fullWidth: true,
              ),
              const SizedBox(height: 12),
              ProtoButton(
                text: 'Cerrar sesión',
                icon: Icons.logout,
                onPressed: () => context.go('/ingresar'),
                fullWidth: true,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              ProtoButton(
                text: 'Perdí mi teléfono',
                icon: Icons.phone_disabled,
                onPressed: () {},
                fullWidth: true,
                secondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
