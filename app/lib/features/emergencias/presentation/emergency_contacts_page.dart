import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/network/idempotency.dart';
import 'package:vecinal/core/ui/large_button.dart';
import 'package:vecinal/features/emergencias/data/emergency_contacts.dart';
import 'package:vecinal/features/emergencias/data/emergency_providers.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_widgets.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class EmergencyContactsPage extends StatelessWidget {
  const EmergencyContactsPage({super.key});
  @override
  Widget build(BuildContext context) => EmergencyScopeGate(
    title: AppLocalizations.of(context).emergencyContacts,
    builder: (scope) => _Contacts(scope: scope),
  );
}

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
  String? _editingId;
  bool _busy = false;
  String? _error;
  bool get _current => mounted && ref.read(emergencyScopeProvider)?.key == widget.scope.key;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _reset() {
    _name.clear();
    _phone.clear();
    _editingId = null;
    _error = null;
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repository = ref.watch(emergencyContactsRepositoryProvider);
    final contacts = ref.watch(emergencyContactsProvider);
    ref.listen(emergencyContactsProvider, (_, next) {
      if (next.hasValue &&
          next.value!.isEmpty &&
          (_name.text.isNotEmpty || _phone.text.isNotEmpty)) {
        setState(_reset);
      }
    });
    final canEdit = repository != null && !contacts.isLoading && !contacts.hasError;
    return EmergencyLayout(
      title: t.emergencyContacts,
      children: [
        Text(widget.scope.practice ? t.emergencyPracticeContacts : t.emergencyContactsPrivacy),
        if (repository == null) Text(t.emergencyContactsUnavailable),
        contacts.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text(t.emergencyContactsUnavailable),
          data: (items) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (items.isEmpty) Text(t.emergencyContactsEmpty),
              for (final contact in items)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(contact.name, style: Theme.of(context).textTheme.titleLarge),
                        Text(contact.phone),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(t.emergencyEditContact),
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _editingId = contact.id;
                                      _name.text = contact.name;
                                      _phone.text = contact.phone;
                                      _error = null;
                                    }),
                            ),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.delete_outline),
                              label: Text(t.emergencyRemoveContact),
                              onPressed: _busy ? null : () => _remove(contact.id),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(),
        Semantics(
          header: true,
          child: Text(
            _editingId == null ? t.emergencyAddContact : t.emergencyEditContact,
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                enabled: !_busy && canEdit,
                maxLength: 80,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: t.emergencyContactName),
                validator: (value) =>
                    EmergencyContact.validName(value ?? '') ? null : t.emergencyContactNameInvalid,
              ),
              TextFormField(
                controller: _phone,
                enabled: !_busy && canEdit,
                maxLength: 16,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: t.emergencyContactPhone),
                validator: (value) => EmergencyContact.validPhone((value ?? '').trim())
                    ? null
                    : t.emergencyContactPhoneInvalid,
              ),
            ],
          ),
        ),
        if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
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
    );
  }

  Future<void> _save() async {
    if (!_current || _busy || !_form.currentState!.validate()) return;
    final repository = ref.read(emergencyContactsRepositoryProvider);
    if (repository == null) return;
    final t = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository.save(
        EmergencyContact(
          id: _editingId ?? newLocalId(),
          name: _name.text.trim(),
          phone: _phone.text.trim(),
        ),
      );
      if (_current) {
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
