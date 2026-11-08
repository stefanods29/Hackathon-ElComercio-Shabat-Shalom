import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla "Acciones por revisar" — bandeja de publicaciones rechazadas o pendientes.
class ActionsToReviewScreen extends StatelessWidget {
  const ActionsToReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Acciones por revisar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'No tienes acciones por revisar',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Cuando una publicación sea rechazada o necesite corrección, '
                'aquí verás el motivo y una alternativa para volver a intentarlo.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
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
    );
  }
}
