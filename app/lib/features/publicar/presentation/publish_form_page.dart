import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/features/solidaridad/data/providers.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/domain/use_cases.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Formulario mínimo de publicación (toque 3 del flujo).
///
/// Viene prellenado con categoría y título sugeridos para que el vecino
/// solo tenga que tocar "Publicar".
class PublishFormPage extends ConsumerStatefulWidget {
  const PublishFormPage({super.key, required this.type});

  final PostType type;

  @override
  ConsumerState<PublishFormPage> createState() => _PublishFormPageState();
}

class _PublishFormPageState extends ConsumerState<PublishFormPage> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _errorTitle;
  String? _errorCategory;
  String? _errorDescription;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final suggestion = suggestionForType(widget.type);
    _titleController.text = suggestion.title;
    _categoryController.text = suggestion.category;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _errorTitle = null;
      _errorCategory = null;
      _errorDescription = null;
    });

    final title = _titleController.text.trim();
    final category = _categoryController.text.trim().toLowerCase();
    final description = _descriptionController.text.trim();

    // Validación local con las mismas reglas que el servidor.
    if (title.length < 3 || title.length > 120) {
      setState(() => _errorTitle = 'El título debe tener entre 3 y 120 caracteres.');
      return;
    }
    if (category.length < 2 || category.length > 40) {
      setState(() => _errorCategory = 'Elige una categoría.');
      return;
    }
    if (description.length > 2000) {
      setState(() => _errorDescription = 'La descripción no puede pasar de 2000 caracteres.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final useCase = PublishPost(ref.read(postRepositoryProvider));
      await useCase.execute(NewPost(
        type: widget.type,
        category: category,
        title: title,
        description: description.isEmpty ? null : description,
      ));
      if (!mounted) return;
      context.go(Routes.home);
    } on LocalValidationError catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _applyFieldError(error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar: $error')),
      );
    }
  }

  void _applyFieldError(LocalValidationError error) {
    switch (error.field) {
      case 'title':
        setState(() => _errorTitle = error.message);
      case 'category':
        setState(() => _errorCategory = error.message);
      case 'description':
        setState(() => _errorDescription = error.message);
      case null:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final suggestion = suggestionForType(widget.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.publishAction),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.type.apiValue.toUpperCase()} · ${suggestion.category}',
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 4),
          Text(
            texts.publishFormTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _titleController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: texts.titleLabel,
              errorText: _errorTitle,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _categoryController,
            decoration: InputDecoration(
              labelText: texts.categoryLabel,
              errorText: _errorCategory,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              labelText: texts.descriptionLabel,
              hintText: texts.descriptionHint,
              errorText: _errorDescription,
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSubmitting ? null : _publish,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(texts.publishButton),
            ),
          ),
        ],
      ),
    );
  }
}
