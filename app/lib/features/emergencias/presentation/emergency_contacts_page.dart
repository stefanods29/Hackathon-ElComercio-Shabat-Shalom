import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/platform/device_services.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/cuenta/presentation/profile_page.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

String relationshipLabel(AppLocalizations t, ContactRelationship relationship) =>
    switch (relationship) {
      ContactRelationship.father => t.relationshipFather,
      ContactRelationship.mother => t.relationshipMother,
      ContactRelationship.guardian => t.relationshipGuardian,
      ContactRelationship.spouse => t.relationshipSpouse,
      ContactRelationship.brother => t.relationshipBrother,
      ContactRelationship.sister => t.relationshipSister,
      ContactRelationship.child => t.relationshipChild,
      ContactRelationship.friend => t.relationshipFriend,
      ContactRelationship.grandparent => t.relationshipGrandparent,
      ContactRelationship.uncleAunt => t.relationshipUncleAunt,
      ContactRelationship.cousin => t.relationshipCousin,
      ContactRelationship.other => t.relationshipOther,
    };

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyContactsTitle,
    builder: (scope) => _Contacts(scope: scope),
  );
}

/// Hides the character counter: the limit still applies, but "0/80" is only noise here.
Widget? _noCounter(
  BuildContext context, {
  required int currentLength,
  required bool isFocused,
  required int? maxLength,
}) => null;

class _Contacts extends ConsumerStatefulWidget {
  const _Contacts({required this.scope});
  final EmergencyScope scope;
  @override
  ConsumerState<_Contacts> createState() => _ContactsState();
}

class _ContactsState extends ConsumerState<_Contacts> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _alternate = TextEditingController();
  ContactRelationship? _relationship;
  String? _editingId;
  bool _busy = false;
  bool _picking = false;
  String? _error;
  bool get _current => mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _alternate.dispose();
    super.dispose();
  }

  void _reset() {
    _name.clear();
    _phone.clear();
    _alternate.clear();
    _relationship = null;
    _editingId = null;
    _error = null;
  }

  void _edit(EmergencyContact contact) => setState(() {
    _editingId = contact.id;
    _name.text = contact.name;
    _phone.text = contact.phone;
    _alternate.text = contact.alternatePhone ?? '';
    _relationship = contact.relationship;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final repository = ref.watch(emergencyContactsRepositoryProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    ref.listen(emergencyContactsProvider, (_, next) {
      if (next.hasValue &&
          next.value!.isEmpty &&
          (_name.text.isNotEmpty || _phone.text.isNotEmpty || _alternate.text.isNotEmpty)) {
        setState(_reset);
      }
    });
    final canEdit = repository != null && !contacts.isLoading && !contacts.hasError;
    return EmergencyLayout(
      title: t.emergencyContactsTitle,
      children: [
        EmergencyNotice(
          icon: widget.scope.practice ? Icons.science_outlined : Icons.lock_outline,
          text: widget.scope.practice ? t.emergencyPracticeContacts : t.emergencyContactsPrivacy,
          tone: NoticeTone.info,
        ),
        if (repository == null)
          EmergencyNotice(icon: Icons.error_outline, text: t.emergencyContactsUnavailable),
        contacts.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(t.emergencyContactsUnavailable),
          data: (items) => items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    spacing: 10,
                    children: [
                      ExcludeSemantics(
                        child: Icon(
                          Icons.contact_phone_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(t.emergencyContactsEmpty, textAlign: TextAlign.center),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    for (final contact in items)
                      _ContactCard(
                        contact: contact,
                        onEdit: _busy ? null : () => _edit(contact),
                        onRemove: _busy ? null : () => _remove(contact.id),
                      ),
                  ],
                ),
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    _editingId == null ? t.emergencyAddContact : t.emergencyEditContact,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                OutlinedButton.icon(
                  icon: _picking
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : const Icon(Icons.contacts_outlined),
                  label: Text(t.emergencyPickFromPhone),
                  onPressed: _busy || _picking || !canEdit ? null : _pickFromPhone,
                ),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 16,
                    children: [
                      TextFormField(
                        controller: _name,
                        enabled: !_busy && canEdit,
                        maxLength: 80,
                        buildCounter: _noCounter,
                        textCapitalization: TextCapitalization.words,
                        decoration: InputDecoration(
                          labelText: t.emergencyContactName,
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                        validator: (value) => EmergencyContact.validName(value ?? '')
                            ? null
                            : t.emergencyContactNameInvalid,
                      ),
                      _RelationshipPicker(
                        value: _relationship,
                        onChanged: _busy || !canEdit
                            ? null
                            : (value) => setState(() => _relationship = value),
                      ),
                      TextFormField(
                        controller: _phone,
                        enabled: !_busy && canEdit,
                        maxLength: 20,
                        buildCounter: _noCounter,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: t.emergencyContactPhone,
                          prefixIcon: const Icon(Icons.phone_outlined),
                          errorMaxLines: 3,
                        ),
                        validator: (value) =>
                            EmergencyContact.validPhone(
                              EmergencyContact.normalizePhone(value ?? ''),
                            )
                            ? null
                            : t.emergencyContactPhoneInvalid,
                      ),
                      TextFormField(
                        controller: _alternate,
                        enabled: !_busy && canEdit,
                        maxLength: 20,
                        buildCounter: _noCounter,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: t.emergencyContactAlternatePhone,
                          prefixIcon: const Icon(Icons.phone_forwarded_outlined),
                          errorMaxLines: 3,
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          return text.isEmpty ||
                                  EmergencyContact.validPhone(EmergencyContact.normalizePhone(text))
                              ? null
                              : t.emergencyContactPhoneInvalid;
                        },
                      ),
                    ],
                  ),
                ),
                if (_error != null)
                  EmergencyNotice(
                    icon: Icons.error_outline,
                    text: _error!,
                    tone: NoticeTone.danger,
                    liveRegion: true,
                  ),
                LargeButton(
                  icon: Icons.save_outlined,
                  label: t.emergencySaveContact,
                  onPressed: _busy || !canEdit ? null : _save,
                ),
                if (_editingId != null)
                  OutlinedButton.icon(
                    icon: const Icon(Icons.cancel_outlined),
                    label: Text(t.cancelAction),
                    onPressed: _busy ? null : () => setState(_reset),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Fills the form from the phone's own contact picker; the neighbor still reviews and saves.
  Future<void> _pickFromPhone() async {
    final t = AppLocalizations.of(context);
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await ref.read(contactPickerProvider).pick();
      if (picked == null || !_current) return;
      // The agenda may keep one number twice, written in two ways.
      final phones = {
        for (final phone in picked.phones)
          if (EmergencyContact.validPhone(EmergencyContact.normalizePhone(phone)))
            EmergencyContact.normalizePhone(phone),
      }.toList();
      setState(() {
        if (picked.name.isNotEmpty) {
          _name.text = picked.name.length > 80 ? picked.name.substring(0, 80) : picked.name;
        }
        if (phones.isNotEmpty) _phone.text = phones.first;
        _alternate.text = phones.length > 1 ? phones[1] : '';
        if (phones.isEmpty) _error = t.emergencyPickedWithoutPhone;
      });
    } catch (_) {
      if (_current) setState(() => _error = t.emergencyPickFailed);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (!_current || _busy || !_form.currentState!.validate()) return;
    final repository = ref.read(emergencyContactsRepositoryProvider);
    if (repository == null) return;
    final t = AppLocalizations.of(context);
    final phone = EmergencyContact.normalizePhone(_phone.text);
    final alternate = EmergencyContact.normalizePhone(_alternate.text);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.save(
        EmergencyContact(
          id: _editingId ?? newLocalId(),
          name: _name.text.trim(),
          phone: phone,
          relationship: _relationship,
          alternatePhone: alternate.isEmpty || alternate == phone ? null : alternate,
        ),
      );
      if (_current && mounted) {
        setState(_reset);
        emergencyMessage(context, t.emergencyContactSaved);
      }
    } catch (_) {
      if (_current) setState(() => _error = t.emergencyContactsUnavailable);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }

  Future<void> _remove(String id) async {
    final t = AppLocalizations.of(context);
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: Text(t.emergencyRemoveContact),
        content: Text(t.emergencyRemoveContactHelp),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(t.cancelAction)),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: Text(t.emergencyRemoveContact),
          ),
        ],
      ),
    );
    if (accepted != true || !_current) return;
    final repository = ref.read(emergencyContactsRepositoryProvider);
    if (repository == null) return;
    setState(() => _busy = true);
    try {
      await repository.remove(id);
      if (_current && _editingId == id) setState(_reset);
    } catch (_) {
      if (_current) setState(() => _error = t.emergencyContactsUnavailable);
    } finally {
      if (_current) setState(() => _busy = false);
    }
  }
}

/// A saved contact: who they are to the neighbor and the numbers to call.
class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.contact, required this.onEdit, required this.onRemove});
  final EmergencyContact contact;
  final VoidCallback? onEdit;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final relationship = contact.relationship;
    final alternate = contact.alternatePhone;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 6, 12),
        child: Row(
          children: [
            ProfileAvatar(name: contact.name, radius: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 2,
                children: [
                  Text(
                    contact.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    relationship == null
                        ? contact.phone
                        : '${relationshipLabel(t, relationship)} · ${contact.phone}',
                  ),
                  if (alternate != null)
                    Text(
                      t.emergencyContactAlternateShort(alternate),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            IconButton(
              tooltip: t.emergencyEditContact,
              icon: const Icon(Icons.edit_outlined),
              onPressed: onEdit,
            ),
            IconButton(
              tooltip: t.emergencyRemoveContact,
              icon: const Icon(Icons.delete_outline),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// Parentesco with one tap: the options as chips, never a drop-down list.
class _RelationshipPicker extends StatelessWidget {
  const _RelationshipPicker({required this.value, required this.onChanged});
  final ContactRelationship? value;
  final ValueChanged<ContactRelationship?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 8,
      children: [
        Text(t.emergencyContactRelationship, style: const TextStyle(fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final relationship in ContactRelationship.values)
              ChoiceChip(
                label: Text(
                  relationshipLabel(t, relationship),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: value == relationship ? scheme.onSecondary : scheme.onSurface,
                  ),
                ),
                selected: value == relationship,
                showCheckmark: false,
                selectedColor: scheme.secondary,
                onSelected: onChanged == null
                    ? null
                    : (selected) => onChanged!(selected ? relationship : null),
              ),
          ],
        ),
      ],
    );
  }
}
