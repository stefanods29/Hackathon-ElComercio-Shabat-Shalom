import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de bienvenida del prototipo Winki. Punto de entrada del flujo.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const WinkiLogo(size: 80, withText: true),
                const SizedBox(height: 24),
                Text(
                  'Servicios, solidaridad y emergencias para tu barrio',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: kTextSecondaryColor),
                ),
                const SizedBox(height: 48),
                ProtoButton(
                  text: 'Comenzar',
                  icon: Icons.login,
                  onPressed: () => context.go('/ingresar'),
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                ProtoButton(
                  text: 'Entrar como visitante',
                  icon: Icons.person_outline,
                  onPressed: () => context.go('/elegir-zona'),
                  fullWidth: true,
                  secondary: true,
                ),
                const SizedBox(height: 48),
                Text(
                  '© 2026 Winki · App vecinal de solidaridad',
                  style: TextStyle(fontSize: 10, color: kTextSecondaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
