import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de bienvenida del prototipo. Punto de entrada del flujo.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
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
                    color: kPrimaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(
                    Icons.house_outlined,
                    size: 40,
                    color: kPrimaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Vecinal',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: kTextColor,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Servicios, solidaridad y emergencias para tu barrio',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 40),
                ProtoButton(
                  text: 'Comenzar',
                  icon: Icons.login,
                  onPressed: () => context.go('/ingresar'),
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                ProtoButton(
                  text: 'Entrar como visitante',
                  icon: Icons.person_outline,
                  onPressed: () => context.go('/elegir-zona'),
                  fullWidth: true,
                  secondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
