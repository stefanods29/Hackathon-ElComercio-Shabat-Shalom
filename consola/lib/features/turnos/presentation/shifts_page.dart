import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/turnos/data/shifts_providers.dart';
import 'package:vecinal_consola/features/turnos/domain/shifts.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Shifts of the zone and the coverage rule of section 9.3.
class ShiftsPage extends ConsumerWidget {
  const ShiftsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(shiftsRepositoryProvider) == null) {
      return ConsolePage(
        title: l10n.shiftsTitle,
        child: ModuleUnavailable(message: l10n.shiftsUnavailable),
      );
    }
    final board = ref.watch(shiftBoardProvider);
    final latest = board.value;
    return ConsolePage(
      title: l10n.shiftsTitle,
      subtitle: latest == null ? null : l10n.updatedAt(formatClock(latest.updatedAt)),
      actions: [
        FilledButton.icon(
          onPressed: latest == null
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (_) => _NewShiftDialog(board: latest),
                ),
          icon: const Icon(Icons.add),
          label: Text(l10n.shiftsNew),
        ),
        OutlinedButton.icon(
          onPressed: () => ref.invalidate(shiftBoardProvider),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refresh),
        ),
      ],
      child: AsyncBody(
        value: board,
        onRetry: () => ref.invalidate(shiftBoardProvider),
        data: (loaded) {
          final now = ref.read(clockProvider)();
          final open = [
            for (final shift in loaded.shifts)
              if (shift.stateAt(now) != ShiftState.finished) shift,
          ];
          final finished = [
            for (final shift in loaded.shifts)
              if (shift.stateAt(now) == ShiftState.finished) shift,
          ];
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              _CoverageCard(coverage: coverageOf(loaded, now)),
              SectionHeading(l10n.shiftsOpenTitle),
              if (open.isEmpty)
                InfoCard(icon: Icons.event_busy_outlined, title: l10n.shiftsNoneOpen)
              else
                for (final shift in open) _ShiftCard(shift: shift, now: now),
              SectionHeading(l10n.shiftsFinishedTitle),
              if (finished.isEmpty)
                Text(l10n.shiftsNoneFinished)
              else
                for (final shift in finished) _ShiftCard(shift: shift, now: now),
            ],
          );
        },
      ),
    );
  }
}

class _CoverageCard extends StatelessWidget {
  const _CoverageCard({required this.coverage});

  final Coverage coverage;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final covered = coverage.covered;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StatusBadge(
              icon: covered ? Icons.verified_outlined : Icons.warning_amber_outlined,
              label: covered ? l10n.coverageYes : l10n.coverageNo,
              tone: covered ? BadgeTone.success : BadgeTone.danger,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.coverageCoordinators(coverage.activeCoordinators, Coverage.requiredCoordinators),
              style: textTheme.bodyLarge,
            ),
            Text(
              coverage.hasCurrentShift ? l10n.coverageShiftYes : l10n.coverageShiftNo,
              style: textTheme.bodyLarge,
            ),
            for (final gap in coverage.gaps)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  switch (gap) {
                    CoverageGap.tooFewCoordinators => l10n.coverageGapCoordinators,
                    CoverageGap.noCurrentShift => l10n.coverageGapShift,
                  },
                  style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 12),
            Text(l10n.coverageRuleNote, style: textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends ConsumerWidget {
  const _ShiftCard({required this.shift, required this.now});

  final Shift shift;
  final DateTime now;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final state = shift.stateAt(now);
    final ended = shift.endedAt;
    return FocusableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shift.personName, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(icon: Icons.badge_outlined, label: roleLabel(l10n, shift.role)),
              StatusBadge(
                icon: switch (state) {
                  ShiftState.current => Icons.play_circle_outline,
                  ShiftState.scheduled => Icons.schedule,
                  ShiftState.finished => Icons.check_circle_outline,
                },
                label: switch (state) {
                  ShiftState.current => l10n.shiftCurrent,
                  ShiftState.scheduled => l10n.shiftScheduled,
                  ShiftState.finished => l10n.shiftFinished,
                },
                tone: state == ShiftState.current ? BadgeTone.success : BadgeTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.shiftWindow(formatDayAndClock(shift.startsAt), formatDayAndClock(shift.endsAt)),
            style: textTheme.bodyLarge,
          ),
          if (ended != null)
            Text(l10n.shiftEndedEarly(formatDayAndClock(ended)), style: textTheme.bodyLarge),
          if (state != ShiftState.finished) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => _EndShiftDialog(shift: shift),
              ),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(l10n.shiftEnd),
            ),
          ],
        ],
      ),
    );
  }
}

class _EndShiftDialog extends ConsumerStatefulWidget {
  const _EndShiftDialog({required this.shift});

  final Shift shift;

  @override
  ConsumerState<_EndShiftDialog> createState() => _EndShiftDialogState();
}

class _EndShiftDialogState extends ConsumerState<_EndShiftDialog> {
  final _key = newLocalId();
  bool _sending = false;
  Object? _error;

  Future<void> _end() async {
    final repository = ref.read(shiftsRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await repository.end(widget.shift, idempotencyKey: _key);
      ref.invalidate(shiftBoardProvider);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    final conflict = isVersionConflict(error);
    return AlertDialog(
      title: Text(l10n.shiftEndTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.shiftEndBody(widget.shift.personName)),
              if (error != null) ...[
                const SizedBox(height: 12),
                ProblemNotice(error: error),
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
        if (conflict)
          FilledButton(
            onPressed: () {
              ref.invalidate(shiftBoardProvider);
              Navigator.of(context).pop();
            },
            child: Text(l10n.reloadList),
          )
        else
          FilledButton(
            onPressed: _sending ? null : _end,
            child: Text(_sending ? l10n.sending : l10n.shiftEnd),
          ),
      ],
    );
  }
}

class _NewShiftDialog extends ConsumerStatefulWidget {
  const _NewShiftDialog({required this.board});

  final ShiftBoard board;

  @override
  ConsumerState<_NewShiftDialog> createState() => _NewShiftDialogState();
}

class _NewShiftDialogState extends ConsumerState<_NewShiftDialog> {
  static const _durations = [Duration(hours: 4), Duration(hours: 8), Duration(hours: 12)];

  String _key = newLocalId();
  String? _personId;
  DateTime? _startsAt;
  Duration _duration = _durations[1];
  String? _validation;
  bool _sending = false;
  Object? _error;

  /// A different draft is a different change: it gets its own key.
  void _change(VoidCallback update) => setState(() {
    update();
    _key = newLocalId();
    _validation = null;
  });

  Future<void> _pickStart() async {
    final now = ref.read(clockProvider)();
    final day = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 30)),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(now));
    if (time == null || !mounted) return;
    _change(() => _startsAt = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(shiftsRepositoryProvider);
    final zoneId = ref.read(currentOperatorProvider)?.zoneId;
    final person = _personId;
    if (repository == null || zoneId == null) return;
    if (person == null) {
      setState(() => _validation = l10n.choosePerson);
      return;
    }
    final start = _startsAt ?? ref.read(clockProvider)();
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await repository.create(
        zoneId,
        ShiftDraft(personId: person, startsAt: start, endsAt: start.add(_duration)),
        idempotencyKey: _key,
      );
      ref.invalidate(shiftBoardProvider);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final people = [
      for (final person in widget.board.operators)
        if (person.active) person,
    ];
    final start = _startsAt;
    final error = _error;
    return AlertDialog(
      title: Text(l10n.shiftsNew),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.choosePerson, style: textTheme.labelLarge),
              const SizedBox(height: 8),
              if (people.isEmpty)
                InfoCard(icon: Icons.group_off_outlined, title: l10n.nobodyAvailable)
              else
                for (final person in people)
                  Semantics(
                    inMutuallyExclusiveGroup: true,
                    checked: person.id == _personId,
                    child: ListTile(
                      leading: Icon(
                        person.id == _personId
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(person.displayName),
                      subtitle: Text(roleLabel(l10n, person.role)),
                      selected: person.id == _personId,
                      onTap: () => _change(() => _personId = person.id),
                    ),
                  ),
              const SizedBox(height: 16),
              Text(l10n.shiftStartLabel, style: textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(start == null ? l10n.shiftStartNow : formatDayAndClock(start)),
                  OutlinedButton(onPressed: _pickStart, child: Text(l10n.shiftPickStart)),
                  if (start != null)
                    TextButton(
                      onPressed: () => _change(() => _startsAt = null),
                      child: Text(l10n.shiftStartNow),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ChoiceRow<Duration>(
                label: l10n.shiftDurationLabel,
                options: _durations,
                selected: _duration,
                labelOf: (duration) => l10n.durationHours(duration.inHours),
                onSelected: (duration) => _change(() => _duration = duration),
              ),
              if (_validation case final message?) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                ProblemNotice(error: error),
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
          onPressed: _sending ? null : _create,
          child: Text(_sending ? l10n.sending : l10n.shiftCreate),
        ),
      ],
    );
  }
}
