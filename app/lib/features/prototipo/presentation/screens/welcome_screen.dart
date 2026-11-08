import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de bienvenida del prototipo. Punto de entrada del flujo.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.house_outlined, size: 80, color: Color(0xFF0B5FAD)),
                const SizedBox(height: 24),
                const Text('Vecinal', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                const Text(
                  'Servicios, solidaridad y emergencias para tu barrio',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 40),
                ProtoButton(
                  text: 'Comenzar',
                  icon: Icons.login,
                  onPressed: () => context.go('/ingresar'),
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => context.go('/elegir-zona'),
                  child: const Text('Entrar como visitante'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
