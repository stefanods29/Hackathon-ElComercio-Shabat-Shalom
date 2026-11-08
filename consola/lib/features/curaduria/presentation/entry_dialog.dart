import 'package:flutter/material.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/curaduria/domain/directory.dart';
import 'package:vecinal_consola/features/curaduria/presentation/curation_labels.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Edits one entry. It returns the entry only when it passes the same checks as the schema.
Future<DirectoryEntry?> showEntryDialog(
  BuildContext context, {
  DirectoryEntry? entry,
  required List<String> otherIds,
  required DateTime now,
}) => showDialog<DirectoryEntry>(
  context: context,
  builder: (_) => EntryDialog(entry: entry, otherIds: otherIds, now: now),
);

class EntryDialog extends StatefulWidget {
  const EntryDialog({super.key, this.entry, required this.otherIds, required this.now});

  final DirectoryEntry? entry;
  final List<String> otherIds;
  final DateTime now;

  @override
  State<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends State<EntryDialog> {
  late final DirectoryEntry? _initial = widget.entry;
  late final _id = TextEditingController(text: _initial?.id ?? '');
  late final _name = TextEditingController(text: _initial?.name ?? '');
  late final _phone = TextEditingController(text: _initial?.phone ?? '');
  late final _lat = TextEditingController(text: _initial?.location?.lat.toString() ?? '');
  late final _lng = TextEditingController(text: _initial?.location?.lng.toString() ?? '');
  late final _address = TextEditingController(text: _initial?.address ?? '');
  late final _description = TextEditingController(text: _initial?.description ?? '');
  late final _sourceName = TextEditingController(text: _initial?.sourceName ?? '');
  late final _sourceUrl = TextEditingController(text: _initial?.sourceUrl ?? '');
  late final _verified = TextEditingController(text: _initial?.verifiedOn ?? '');
  late EntryType _type = _initial?.type ?? EntryType.meetingPoint;

  /// A new entry suggests its id from the name until the curator writes one.
  late bool _idTouched = _initial != null;
  List<EntryProblem> _problems = const [];

  @override
  void dispose() {
    for (final controller in [
      _id,
      _name,
      _phone,
      _lat,
      _lng,
      _address,
      _description,
      _sourceName,
      _sourceUrl,
      _verified,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _optional(TextEditingController controller) {
    final text = controller.text.trim();
    return text.isEmpty ? null : text;
  }

  double? _coordinate(TextEditingController controller) =>
      double.tryParse(controller.text.trim().replaceAll(',', '.'));

  void _save() {
    final problems = <EntryProblem>[];
    EntryLocation? location;
    final latText = _lat.text.trim();
    final lngText = _lng.text.trim();
    if (latText.isNotEmpty || lngText.isNotEmpty) {
      final lat = _coordinate(_lat);
      final lng = _coordinate(_lng);
      if (lat == null) problems.add(const EntryProblem('ubicacion.lat', EntryProblemKind.latitudeRange));
      if (lng == null) {
        problems.add(const EntryProblem('ubicacion.lng', EntryProblemKind.longitudeRange));
      }
      if (lat != null && lng != null) location = EntryLocation(lat: lat, lng: lng);
    }
    final entry = DirectoryEntry(
      id: _id.text.trim(),
      type: _type,
      name: _name.text.trim(),
      phone: _optional(_phone),
      location: location,
      address: _optional(_address),
      description: _optional(_description),
      sourceName: _sourceName.text.trim(),
      sourceUrl: _optional(_sourceUrl),
      verifiedOn: _verified.text.trim(),
    );
    problems.addAll(
      validateEntry(entry, today: isoDay(widget.now), otherIds: widget.otherIds),
    );
    if (problems.isNotEmpty) {
      setState(() => _problems = problems);
      return;
    }
    Navigator.of(context).pop(entry);
  }

  String? _errorFor(AppLocalizations l10n, List<String> fields) {
    for (final problem in _problems) {
      if (fields.contains(problem.field)) return entryProblemText(l10n, problem.kind);
    }
    return null;
  }

  Future<void> _pickDay() async {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final current = DateTime.tryParse(_verified.text.trim());
    final day = await showDatePicker(
      context: context,
      initialDate: current != null && !current.isAfter(today) ? current : today,
      firstDate: DateTime(2020),
      lastDate: today,
    );
    if (day != null && mounted) setState(() => _verified.text = isoDay(day));
  }

  Widget _field(
    AppLocalizations l10n,
    TextEditingController controller,
    String label, {
    List<String> fields = const [],
    String? helper,
    TextInputType? keyboard,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: controller,
      keyboardType: keyboard,
      maxLines: maxLines,
      enableSuggestions: false,
      onChanged: onChanged,
      decoration: fieldDecoration(label, helper: helper, error: _errorFor(l10n, fields)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needsPhone = _type == EntryType.number;
    final hasProblems = _problems.isNotEmpty;
    return AlertDialog(
      title: Text(_initial == null ? l10n.entryNew : l10n.entryEdit),
      content: SizedBox(
        width: 640,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasProblems) ...[
                Semantics(
                  liveRegion: true,
                  child: InfoCard(
                    icon: Icons.error_outline,
                    title: l10n.entryHasProblems(_problems.length),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ChoiceRow<EntryType>(
                label: l10n.entryFieldType,
                options: EntryType.values,
                selected: _type,
                labelOf: (type) => entryTypeLabel(l10n, type),
                onSelected: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: 16),
              _field(
                l10n,
                _name,
                l10n.entryFieldName,
                fields: const ['nombre'],
                onChanged: (name) {
                  if (!_idTouched) _id.text = suggestId(name);
                },
              ),
              _field(
                l10n,
                _id,
                l10n.entryFieldId,
                fields: const ['id'],
                helper: l10n.entryIdHelp,
                onChanged: (_) => _idTouched = true,
              ),
              _field(
                l10n,
                _phone,
                needsPhone ? l10n.entryFieldPhoneRequired : l10n.entryFieldPhoneOptional,
                fields: const ['telefono'],
                helper: l10n.entryPhoneHelp,
                keyboard: TextInputType.phone,
              ),
              Text(
                needsPhone ? l10n.entryLocationOptional : l10n.entryLocationRequired,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 16,
                children: [
                  SizedBox(
                    width: 260,
                    child: _field(
                      l10n,
                      _lat,
                      l10n.entryFieldLatitude,
                      fields: const ['ubicacion', 'ubicacion.lat'],
                      keyboard: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    child: _field(
                      l10n,
                      _lng,
                      l10n.entryFieldLongitude,
                      fields: const ['ubicacion', 'ubicacion.lng'],
                      keyboard: const TextInputType.numberWithOptions(signed: true, decimal: true),
                    ),
                  ),
                ],
              ),
              _field(l10n, _address, l10n.entryFieldAddress, fields: const ['direccion']),
              _field(
                l10n,
                _description,
                l10n.entryFieldDescription,
                fields: const ['descripcion'],
                maxLines: 3,
              ),
              _field(
                l10n,
                _sourceName,
                l10n.entryFieldSourceName,
                fields: const ['fuente.nombre'],
                helper: l10n.entrySourceHelp,
              ),
              _field(
                l10n,
                _sourceUrl,
                l10n.entryFieldSourceUrl,
                fields: const ['fuente.url'],
                keyboard: TextInputType.url,
              ),
              _field(
                l10n,
                _verified,
                l10n.entryFieldVerified,
                fields: const ['verificadoEn'],
                helper: l10n.entryVerifiedHelp,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton(
                    onPressed: () => setState(() => _verified.text = isoDay(widget.now)),
                    child: Text(l10n.entryVerifiedToday),
                  ),
                  OutlinedButton(onPressed: _pickDay, child: Text(l10n.entryVerifiedPick)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(onPressed: _save, child: Text(l10n.entrySave)),
      ],
    );
  }
}
