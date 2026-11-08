import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_text_field.dart';
import 'package:vecinal/features/publicar/domain/suggestions.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Shared by the home tab and direct links: open, choose a type, publish.
/// Submission intentionally retains the prototype's simulated confirmation.
class ProtoPublishForm extends StatefulWidget {
  const ProtoPublishForm({
    super.key,
    this.initialType,
    required this.onPublished,
    required this.onCancel,
  });

  final String? initialType;
  final VoidCallback onPublished;
  final VoidCallback onCancel;

  @override
  State<ProtoPublishForm> createState() => _ProtoPublishFormState();
}

class _ProtoPublishFormState extends State<ProtoPublishForm> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String? _selectedType;
  String? _suggestedTitle;
  bool _showTypeError = false;
  bool _showTitleError = false;

  @override
  void initState() {
    super.initState();
    _selectType(widget.initialType);
  }

  @override
  void didUpdateWidget(covariant ProtoPublishForm oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialType != widget.initialType) {
      _selectType(widget.initialType);
    }
  }

  void _selectType(String? value) {
    for (final suggestion in publishSuggestions) {
      if (suggestion.type.name != value && suggestion.type.apiValue != value) {
        continue;
      }
      // Preserve a custom title when the person changes the publication type.
      final title = _titleController.text.trim();
      if (title.isEmpty || title == _suggestedTitle) {
        _titleController.text = suggestion.title;
      }
      _selectedType = suggestion.type.name;
      _suggestedTitle = suggestion.title;
      _showTypeError = false;
      _showTitleError = false;
      return;
    }
  }

  void _publish() {
    final titleLength = _titleController.text.trim().length;
    setState(() {
      _showTypeError = _selectedType == null;
      _showTitleError = titleLength < 3 || titleLength > 120;
    });
    if (_showTypeError || _showTitleError) return;

    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).protoPublished),
        backgroundColor: kSuccessColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
    _reset();
    widget.onPublished();
  }

  void _reset() {
    setState(() {
      _titleController.clear();
      _descriptionController.clear();
      _selectedType = null;
      _suggestedTitle = null;
      _showTitleError = false;
      _showTypeError = false;
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.protoPublishTitle,
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(l10n.protoPublishHint),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth < 500 ? 2 : 3;
                          final gap = 8.0;
                          final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final type in mockPublishTypes)
                                SizedBox(
                                  width: itemWidth,
                                  child: _PublishTypeChoice(
                                    label: type['label']!,
                                    hint: type['hint']!,
                                    selected: _selectedType == type['value'],
                                    onTap: () => setState(() => _selectType(type['value'])),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                      if (_showTypeError) ...[
                        const SizedBox(height: 8),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            l10n.protoChooseTypeError,
                            style: const TextStyle(color: kErrorColor),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ProtoTextField(
                        key: const ValueKey('prototype-publish-title'),
                        label: l10n.titleLabel,
                        hint: l10n.protoTitleHint,
                        controller: _titleController,
                        errorText: _showTitleError ? l10n.protoTitleError : null,
                        onChanged: (_) {
                          if (_showTitleError) setState(() => _showTitleError = false);
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 20),
                      ProtoTextField(
                        label: l10n.protoOptionalDescription,
                        hint: l10n.descriptionHint,
                        controller: _descriptionController,
                        keyboardType: TextInputType.multiline,
                        maxLength: 2000,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ProtoButton(
                        text: l10n.cancelAction,
                        icon: Icons.close,
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          _reset();
                          widget.onCancel();
                        },
                        secondary: true,
                        fullWidth: true,
                      ),
                    ],
                  ),
                ),
              ),
              // Keep the publish action reachable above the home indicator.
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ProtoButton(
                  key: const ValueKey<String>('prototype-publish-submit'),
                  text: l10n.publishButton,
                  icon: Icons.publish_outlined,
                  onPressed: _publish,
                  fullWidth: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PublishTypeChoice extends StatelessWidget {
  const _PublishTypeChoice({
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: OutlinedButton(
      key: ValueKey<String>('publish-type-${label.toLowerCase()}'),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(76),
        padding: const EdgeInsets.all(12),
        backgroundColor: selected ? kPrimaryColor.withValues(alpha: 0.08) : kSurfaceColor,
        side: BorderSide(color: selected ? kPrimaryColor : kBorderColor, width: selected ? 1.5 : 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(kRadiusLarge)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: selected ? kPrimaryColor : kTextColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (selected) const Icon(Icons.check_circle, color: kPrimaryColor, size: 20),
            ],
          ),
          const SizedBox(height: 4),
          Text(hint, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}
