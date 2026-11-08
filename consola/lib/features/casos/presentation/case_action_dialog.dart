import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/casos/data/cases_providers.dart';
import 'package:vecinal_consola/features/casos/domain/cases_repository.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/casos/presentation/case_labels.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Opens the dialog of one action over the version of the case that was on screen.
Future<void> showCaseActionDialog(
  BuildContext context, {
  required EmergencyCase seen,
  required CaseAction action,
}) => showDialog<void>(
  context: context,
  builder: (_) => CaseActionDialog(seen: seen, action: action),
);

/// Sends the action with `versionVista` and an `Idempotency-Key`. If another person changed the
/// case first (409 `conflicto_de_version`), it explains it and reloads the case without losing what
/// was typed; the next attempt goes with the new version and a new key.
class CaseActionDialog extends ConsumerStatefulWidget {
  const CaseActionDialog({super.key, required this.seen, required this.action});

  final EmergencyCase seen;
  final CaseAction action;

  @override
  ConsumerState<CaseActionDialog> createState() => _CaseActionDialogState();
}

class _CaseActionDialogState extends ConsumerState<CaseActionDialog> {
  final _reason = TextEditingController();
  late EmergencyCase _seen = widget.seen;
  String _key = newLocalId();
  String? _personId;
  ReferralLine? _line;
  String? _validation;
  Object? _error;
  bool _sending = false;
  bool _reloading = false;

  CaseAction get _action => widget.action;

  bool get _stillAllowed => actionsFrom(_seen.status).contains(_action);

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  CaseCommand? _command(AppLocalizations l10n) {
    final reason = _reason.text.trim();
    if (needsReason(_action) && reason.length < reasonMinLength) {
      setState(() => _validation = l10n.reasonTooShort(reasonMinLength));
      return null;
    }
    switch (_action) {
      case CaseAction.markSeen:
        return const MarkSeen();
      case CaseAction.assign:
        final person = _personId;
        if (person == null) {
          setState(() => _validation = l10n.choosePerson);
          return null;
        }
        return AssignCase(personId: person, note: reason.isEmpty ? null : reason);
      case CaseAction.refer:
        final line = _line;
        if (line == null) {
          setState(() => _validation = l10n.chooseLine);
          return null;
        }
        return ReferCase(line: line, reason: reason);
      case CaseAction.closeUnattended:
        return CloseUnattended(reason: reason);
    }
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context);
    final command = _command(l10n);
    if (command == null) return;
    setState(() {
      _validation = null;
      _error = null;
      _sending = true;
    });
    try {
      await ref.read(caseCommandsProvider).apply(_seen, command, idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop();
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _error = error;
          _sending = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() => _reloading = true);
    ref.invalidate(caseDetailProvider(_seen.id));
    try {
      final fresh = await ref.read(caseDetailProvider(_seen.id).future);
      if (!mounted) return;
      setState(() {
        _seen = fresh;
        // A different version is a different change: it gets its own key.
        _key = newLocalId();
        _error = null;
      });
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final conflict = isVersionConflict(_error);
    final error = _error;
    final textTheme = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(actionLabel(l10n, _action)),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(actionHelp(l10n, _action), style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              Text(
                l10n.actionOverVersion(statusLabel(l10n, _seen.status), _seen.version),
                style: textTheme.bodyMedium,
              ),
              if (_action == CaseAction.assign) ...[
                const SizedBox(height: 16),
                _PeoplePicker(
                  selected: _personId,
                  onSelected: (id) => setState(() => _personId = id),
                ),
              ],
              if (_action == CaseAction.refer) ...[
                const SizedBox(height: 16),
                ChoiceRow<ReferralLine>(
                  label: l10n.chooseLine,
                  options: ReferralLine.values,
                  selected: _line,
                  labelOf: (line) => lineLabel(l10n, line),
                  onSelected: (line) => setState(() => _line = line),
                ),
              ],
              if (_action != CaseAction.markSeen) ...[
                const SizedBox(height: 16),
                TextField(
                  controller: _reason,
                  enabled: !_sending,
                  minLines: 2,
                  maxLines: 5,
                  maxLength: reasonMaxLength,
                  decoration: fieldDecoration(
                    needsReason(_action) ? l10n.reasonRequiredLabel : l10n.reasonOptionalLabel,
                    helper: needsReason(_action) ? l10n.reasonRequiredHelp : null,
                  ),
                ),
              ],
              if (_validation case final message?)
                Semantics(
                  liveRegion: true,
                  child: Text(
                    message,
                    style: textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              if (!_stillAllowed) ...[
                const SizedBox(height: 12),
                InfoCard(icon: Icons.info_outline, title: l10n.actionNoLongerAvailable),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                ProblemNotice(
                  error: error,
                  onRetry: conflict && !_reloading ? _reload : null,
                  retryLabel: l10n.reloadKeepingText,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _sending || _reloading || conflict || !_stillAllowed ? null : _submit,
          child: Text(_sending ? l10n.sending : l10n.actionConfirm),
        ),
      ],
    );
  }
}

class _PeoplePicker extends ConsumerWidget {
  const _PeoplePicker({required this.selected, required this.onSelected});

  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final people = ref.watch(availablePeopleProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.choosePerson, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        people.when(
          loading: () => const LoadingIndicator(),
          error: (error, _) => ProblemNotice(
            error: error,
            onRetry: () => ref.invalidate(availablePeopleProvider),
          ),
          data: (list) => list.isEmpty
              ? InfoCard(icon: Icons.group_off_outlined, title: l10n.nobodyAvailable)
              : Column(
                  children: [
                    for (final person in list)
                      Semantics(
                        inMutuallyExclusiveGroup: true,
                        checked: person.id == selected,
                        child: ListTile(
                          leading: Icon(
                            person.id == selected
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                          ),
                          title: Text(person.displayName),
                          subtitle: Text(
                            person.onShift
                                ? l10n.personOnShift(assigneeKindLabel(l10n, person.kind))
                                : l10n.personOffShift(assigneeKindLabel(l10n, person.kind)),
                          ),
                          selected: person.id == selected,
                          onTap: () => onSelected(person.id),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
