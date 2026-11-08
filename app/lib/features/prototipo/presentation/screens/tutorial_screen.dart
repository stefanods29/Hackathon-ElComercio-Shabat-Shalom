import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de tutorial — guía de primeros pasos de la app.
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutorial')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bienvenido a Vecinal',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _tutorialStep(1, 'Publicar en 3 toques',
                  'Toca el botón "+", elige el tipo y publica. Tu publicación se guarda en tu celular al instante.'),
              const SizedBox(height: 16),
              _tutorialStep(2, 'Tomar un favor',
                  'En el muro, toca una tarjeta para ver los detalles y ofrecerte a ayudar.'),
              const SizedBox(height: 16),
              _tutorialStep(3, 'Estados visibles',
                  'Si ves "Guardado en tu celular", la publicación todavía no se envió a nadie. Se envía cuando vuelve la señal.'),
              const SizedBox(height: 16),
              _tutorialStep(4, 'Acciones por revisar',
                  'Si una publicación es rechazada, aquí verás el motivo y una alternativa para volver a intentarlo.'),
              const SizedBox(height: 16),
              _tutorialStep(5, 'Emergencia',
                  'Si hay riesgo para la vida, llama al 116, 105 o 106. Esta app conecta vecinos; no reemplaza a los servicios de emergencia.'),
              const Spacer(),
              ProtoButton(
                text: 'Empezar a usar la app',
                icon: Icons.check_circle,
                onPressed: () => Navigator.pop(context),
                fullWidth: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tutorialStep(int step, String title, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: const Color(0xFF0B5FAD),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text('$step',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            ],
          ),
        ),
      ],
    );
  }
}
