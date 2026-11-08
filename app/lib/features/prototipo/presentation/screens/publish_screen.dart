import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_text_field.dart';

/// Pantalla de publicar (flujo de 3 toques simplificado para el prototipo).
/// Toque 1: desde el muro. Toque 2: elegir tipo. Toque 3: formulario y publicar.
class PublishScreen extends StatefulWidget {
  const PublishScreen({super.key});

  @override
  State<PublishScreen> createState() => _PublishScreenState();
}

class _PublishScreenState extends State<PublishScreen> {
  String? selectedType;
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  String? error;

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  void _publish() {
    if (selectedType == null) {
      setState(() => error = 'Selecciona un tipo de publicación.');
      return;
    }
    if (titleController.text.trim().length < 3) {
      setState(() => error = 'El título debe tener entre 3 y 120 caracteres.');
      return;
    }
    setState(() => error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Publicación guardada en tu celular.'),
        backgroundColor: Color(0xFFFFAB00),
      ),
    );
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicar')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '¿Qué quieres compartir?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Elige el tipo y los datos se prellenan.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              // Grilla de tipos (toque 2)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: mockPublishTypes.map((t) {
                  final isSelected = selectedType == t['value'];
                  return ChoiceChip(
                    label: Text(t['label']!),
                    selected: isSelected,
                    onSelected: (_) => setState(() => selectedType = t['value']),
                    labelStyle: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                    selectedColor: const Color(0xFF0B5FAD),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ProtoTextField(
                label: 'Título',
                hint: 'Necesito ayuda con...',
                controller: titleController,
                maxLength: 120,
                errorText: error,
              ),
              const SizedBox(height: 16),
              ProtoTextField(
                label: 'Descripción (opcional)',
                hint: 'Más detalles sobre lo que ofreces o necesitas',
                controller: descriptionController,
                maxLength: 2000,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ProtoButton(
                text: 'Publicar',
                icon: Icons.publish,
                onPressed: _publish,
                fullWidth: true,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => context.go('/'), child: const Text('Cancelar')),
            ],
          ),
        ),
      ),
    );
  }
}
