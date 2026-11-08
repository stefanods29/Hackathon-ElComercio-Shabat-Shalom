import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla "Acciones por revisar" — bandeja de publicaciones rechazadas o pendientes.
class ActionsToReviewScreen extends StatelessWidget {
  const ActionsToReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Acciones por revisar', style: TextStyle(color: kTextColor, fontWeight: FontWeight.bold)),
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
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kWarningColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.error_outline, size: 36, color: kWarningColor),
              ),
              const SizedBox(height: 20),
              const Text(
                'No tienes acciones por revisar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: kTextColor),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Cuando una publicación sea rechazada o necesite corrección, '
                'aquí verás el motivo y una alternativa para volver a intentarlo.',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ProtoButton(
                text: 'Volver al muro',
                icon: Icons.arrow_back,
                onPressed: () => context.go('/muro'),
                fullWidth: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
