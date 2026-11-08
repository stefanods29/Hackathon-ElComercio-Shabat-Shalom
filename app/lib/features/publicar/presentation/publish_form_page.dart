import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
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
  final _formKey = GlobalKey<FormState>();
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
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim().toLowerCase();
    final description = _descriptionController.text.trim();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSubmitting = true);

    try {
      final useCase = PublishPost(ref.read(postRepositoryProvider));
      await useCase.execute(
        NewPost(
          type: widget.type,
          category: category,
          title: title,
          description: description.isEmpty ? null : description,
        ),
      );
      if (!mounted) return;
      context.go(Routes.home);
    } on LocalValidationError catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _applyFieldError(error);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).wallLoadError)));
    }
  }

  void _applyFieldError(LocalValidationError error) {
    switch (error.field) {
      case 'title':
        _formKey.currentState?.validate();
      case 'category':
        _formKey.currentState?.validate();
      case 'description':
        _formKey.currentState?.validate();
      case null:
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).wallLoadError)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final suggestion = suggestionForType(widget.type);

    return Scaffold(
      appBar: AppBar(
        title: Text(texts.publishAction),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(context.vecinalTokens.spaceLg),
                children: [
                  Text(
                    '${widget.type.apiValue.toUpperCase()} · ${suggestion.category}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(texts.publishFormTitle, style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: texts.titleLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.length < 3) return texts.titleLengthError;
                      if (text.length > 120) return texts.titleLengthError;
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _categoryController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    maxLength: 40,
                    decoration: InputDecoration(
                      labelText: texts.categoryLabel,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        (value?.trim().length ?? 0) < 2 ? texts.categoryRequiredError : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionController,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.newline,
                    decoration: InputDecoration(
                      labelText: texts.descriptionLabel,
                      hintText: texts.descriptionHint,
                      border: const OutlineInputBorder(),
                    ),
                    maxLines: 4,
                    maxLength: 2000,
                    validator: (value) =>
                        (value?.length ?? 0) > 2000 ? texts.descriptionTooLongError : null,
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
            ),
          ),
        ),
      ),
    );
  }
}
