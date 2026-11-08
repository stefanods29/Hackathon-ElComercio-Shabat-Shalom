import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
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
      SnackBar(
        content: const Text('Publicación guardada en tu celular.'),
        backgroundColor: kSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    context.go('/mapa');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '¿Qué quieres compartir?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Elige el tipo y los datos se prellenan.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: mockPublishTypes.map((t) {
                    final isSelected = selectedType == t['value'];
                    return ChoiceChip(
                      label: Text(
                        t['label']!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : kTextColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (_) => setState(() => selectedType = t['value']),
                      selectedColor: kPrimaryColor,
                      backgroundColor: kSurfaceColor,
                      labelPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? kPrimaryColor : Colors.grey.shade300,
                        ),
                      ),
                      elevation: 0,
                    );
                  }).toList(),
                ),
                const SizedBox(height: 28),
                ProtoTextField(
                  label: 'Título',
                  hint: 'Necesito ayuda con...',
                  controller: titleController,
                  maxLength: 120,
                  errorText: error,
                ),
                const SizedBox(height: 20),
                ProtoTextField(
                  label: 'Descripción (opcional)',
                  hint: 'Más detalles sobre lo que ofreces o necesitas',
                  controller: descriptionController,
                  maxLength: 2000,
                  maxLines: 3,
                ),
                const SizedBox(height: 28),
                ProtoButton(
                  text: 'Publicar',
                  icon: Icons.publish,
                  onPressed: _publish,
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                ProtoButton(
                  text: 'Cancelar',
                  icon: Icons.close,
                  onPressed: () => context.go('/mapa'),
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
