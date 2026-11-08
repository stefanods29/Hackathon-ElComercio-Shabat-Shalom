import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/network/problem_details.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/curaduria/data/curation_repositories.dart';
import 'package:vecinal_consola/features/curaduria/domain/directory.dart';
import 'package:vecinal_consola/features/curaduria/presentation/curation_labels.dart';
import 'package:vecinal_consola/features/curaduria/presentation/entry_dialog.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Edits a district's directory and publishes the next version with `versionVista`. The draft
/// lives only in this page: nothing is saved in the browser, so signing out discards it.
class DirectoryEditorPage extends ConsumerStatefulWidget {
  const DirectoryEditorPage({super.key, required this.file});

  final String file;

  @override
  ConsumerState<DirectoryEditorPage> createState() => _DirectoryEditorPageState();
}

class _DirectoryEditorPageState extends ConsumerState<DirectoryEditorPage> {
  final _district = TextEditingController();
  PublishedDirectory? _published;
  List<DirectoryEntry> _entries = [];
  int _seenVersion = 0;

  /// Version of someone else that this draft will replace, after a conflict.
  int? _replacingVersion;
  bool _dirty = false;
  bool _loading = true;
  bool _publishing = false;
  bool _showProblems = false;
  Object? _loadError;
  Object? _publishError;
  List<FieldError> _serverErrors = const [];
  String _key = newLocalId();

  bool get _validFile => fileNamePattern.hasMatch(widget.file);

  @override
  void initState() {
    super.initState();
    if (_validFile) {
      _load();
    } else {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _district.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repository = ref.read(curationRepositoryProvider);
    if (repository == null) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final published = await repository.get(widget.file);
      if (mounted) _apply(published);
    } on Object catch (error) {
      if (mounted) setState(() => _loadError = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _apply(PublishedDirectory published) => setState(() {
    _published = published;
    _seenVersion = published.directory.version;
    _replacingVersion = null;
    _district.text = published.directory.district;
    _entries = [...published.directory.entries];
    _dirty = false;
    _showProblems = false;
    _publishError = null;
    _serverErrors = const [];
    _key = newLocalId();
  });

  /// Every change makes a different publication: it gets its own key.
  void _edit(VoidCallback change) => setState(() {
    change();
    _dirty = true;
    _serverErrors = const [];
    _key = newLocalId();
  });

  DateTime _now() => ref.read(clockProvider)();

  Future<void> _editEntry(int? index) async {
    final entry = index == null ? null : _entries[index];
    final others = [
      for (var position = 0; position < _entries.length; position++)
        if (position != index) _entries[position].id,
    ];
    final result = await showEntryDialog(context, entry: entry, otherIds: others, now: _now());
    if (result == null || !mounted) return;
    _edit(() {
      if (index == null) {
        _entries.add(result);
      } else {
        _entries[index] = result;
      }
    });
  }

  Future<void> _removeEntry(int index) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.entryRemoveTitle),
        content: Text(l10n.entryRemoveBody(_entries[index].name)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.entryRemove),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _edit(() => _entries.removeAt(index));
  }

  void _move(int index, int offset) {
    final target = index + offset;
    if (target < 0 || target >= _entries.length) return;
    _edit(() {
      final entry = _entries.removeAt(index);
      _entries.insert(target, entry);
    });
  }

  Future<void> _publish() async {
    final l10n = AppLocalizations.of(context);
    final repository = ref.read(curationRepositoryProvider);
    if (repository == null) return;
    final problems = validateEntries(_entries, today: isoDay(_now()));
    if (!districtIsValid(_district.text) || _entries.isEmpty || problems.isNotEmpty) {
      setState(() => _showProblems = true);
      return;
    }
    setState(() {
      _publishing = true;
      _publishError = null;
    });
    try {
      final published = await repository.publish(
        widget.file,
        seenVersion: _seenVersion,
        district: _district.text.trim(),
        entries: _entries,
        idempotencyKey: _key,
      );
      if (!mounted) return;
      _apply(published);
      ref.invalidate(directoriesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.curationPublished(published.directory.version))),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _publishError = error;
        _serverErrors = error is ApiProblem ? error.problem.fieldErrors : const [];
      });
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  /// After a conflict: keeps this draft and aims it at the version just published by someone else.
  Future<void> _replaceNewVersion() async {
    final repository = ref.read(curationRepositoryProvider);
    if (repository == null) return;
    try {
      final latest = await repository.get(widget.file);
      if (!mounted) return;
      setState(() {
        _seenVersion = latest.directory.version;
        _replacingVersion = latest.directory.version;
        _publishError = null;
        _key = newLocalId();
      });
    } on Object catch (error) {
      if (mounted) setState(() => _publishError = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final back = TextButton.icon(
      onPressed: () => context.go(Routes.curation),
      icon: const Icon(Icons.arrow_back),
      label: Text(l10n.curationBack),
    );
    if (!_validFile) {
      return ConsolePage(
        title: l10n.curationTitle,
        actions: [back],
        child: CenteredMessage(
          child: InfoCard(icon: Icons.search_off, title: l10n.notFoundTitle, body: l10n.notFoundBody),
        ),
      );
    }
    final published = _published;
    final loadError = _loadError;
    final Widget body;
    if (_loading && published == null) {
      body = const LoadingIndicator();
    } else if (published == null) {
      body = CenteredMessage(
        child: ProblemNotice(error: loadError ?? const ModuleNotAvailable(), onRetry: _load),
      );
    } else {
      body = _editor(l10n, published);
    }
    return ConsolePage(
      title: l10n.curationEditorTitle(widget.file),
      subtitle: published == null
          ? null
          : l10n.curationEditorSubtitle(
              published.directory.version,
              formatDayAndClock(published.directory.generatedAt),
            ),
      actions: [back],
      child: body,
    );
  }

  Widget _editor(AppLocalizations l10n, PublishedDirectory published) {
    final textTheme = Theme.of(context).textTheme;
    final today = isoDay(_now());
    final problems = _showProblems
        ? validateEntries(_entries, today: today)
        : const <int, List<EntryProblem>>{};
    final publishError = _publishError;
    final conflict = isVersionConflict(publishError);
    final replacing = _replacingVersion;
    final districtError = _showProblems && !districtIsValid(_district.text)
        ? l10n.curationDistrictInvalid
        : null;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        if (_dirty)
          InfoCard(icon: Icons.edit_note, title: l10n.curationUnsaved, body: l10n.curationUnsavedBody),
        if (replacing != null) ...[
          const SizedBox(height: 12),
          InfoCard(icon: Icons.warning_amber_outlined, title: l10n.curationReplacing(replacing)),
        ],
        const SizedBox(height: 16),
        TextField(
          controller: _district,
          onChanged: (_) => _edit(() {}),
          decoration: fieldDecoration(l10n.curationDistrict, error: districtError),
        ),
        SectionHeading(l10n.curationEntries(_entries.length)),
        if (_showProblems && _entries.isEmpty)
          Text(l10n.curationNeedsEntries, style: textTheme.bodyLarge),
        for (var index = 0; index < _entries.length; index++)
          _EntryCard(
            entry: _entries[index],
            position: index,
            total: _entries.length,
            localProblems: problems[index] ?? const [],
            serverErrors: [
              for (final error in _serverErrors)
                if (error.field.startsWith('entradas.$index.') || error.field == 'entradas.$index')
                  error,
            ],
            onEdit: () => _editEntry(index),
            onRemove: () => _removeEntry(index),
            onMoveUp: index == 0 ? null : () => _move(index, -1),
            onMoveDown: index == _entries.length - 1 ? null : () => _move(index, 1),
          ),
        if (_entries.length < maxEntries)
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _editEntry(null),
              icon: const Icon(Icons.add),
              label: Text(l10n.entryAdd),
            ),
          ),
        const SizedBox(height: 24),
        if (_showProblems && (problems.isNotEmpty || districtError != null)) ...[
          Semantics(
            liveRegion: true,
            child: InfoCard(
              icon: Icons.error_outline,
              title: l10n.curationProblemsBeforePublishing(problems.length),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (publishError != null) ...[
          ProblemNotice(error: publishError),
          if (conflict) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(onPressed: _load, child: Text(l10n.curationDiscardAndReload)),
                FilledButton.tonal(
                  onPressed: _replaceNewVersion,
                  child: Text(l10n.curationKeepMine),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
        ],
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              onPressed: _publishing || conflict ? null : _publish,
              icon: const Icon(Icons.publish_outlined),
              label: Text(
                _publishing ? l10n.sending : l10n.curationPublish(_seenVersion + 1),
              ),
            ),
            if (_dirty)
              TextButton(onPressed: _publishing ? null : _load, child: Text(l10n.curationDiscard)),
          ],
        ),
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.entry,
    required this.position,
    required this.total,
    required this.localProblems,
    required this.serverErrors,
    required this.onEdit,
    required this.onRemove,
    required this.onMoveUp,
    required this.onMoveDown,
  });

  final DirectoryEntry entry;
  final int position;
  final int total;
  final List<EntryProblem> localProblems;
  final List<FieldError> serverErrors;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final location = entry.location;
    final phone = entry.phone;
    final hasProblems = localProblems.isNotEmpty || serverErrors.isNotEmpty;
    final errorStyle = textTheme.bodyMedium?.copyWith(color: scheme.error);
    return FocusableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(entry.name, style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusBadge(icon: Icons.category_outlined, label: entryTypeLabel(l10n, entry.type)),
              StatusBadge(
                icon: Icons.fact_check_outlined,
                label: l10n.entryVerifiedOn(entry.verifiedOn),
              ),
              if (hasProblems)
                StatusBadge(
                  icon: Icons.error_outline,
                  label: l10n.entryProblemsBadge(localProblems.length + serverErrors.length),
                  tone: BadgeTone.danger,
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(l10n.entryPosition(position + 1, total, entry.id), style: textTheme.bodyMedium),
          if (phone != null) Text(l10n.entryPhone(phone), style: textTheme.bodyLarge),
          if (location != null)
            Text(
              l10n.entryCoordinates(location.lat.toStringAsFixed(5), location.lng.toStringAsFixed(5)),
              style: textTheme.bodyLarge,
            ),
          Text(l10n.entrySource(entry.sourceName), style: textTheme.bodyLarge),
          for (final problem in localProblems)
            Text(
              l10n.problemField(
                entryFieldLabel(l10n, problem.field),
                entryProblemText(l10n, problem.kind),
              ),
              style: errorStyle,
            ),
          for (final error in serverErrors)
            Text(
              l10n.problemField(
                entryFieldLabel(l10n, error.field.split('.').skip(2).join('.')),
                error.message,
              ),
              style: errorStyle,
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l10n.entryEdit),
              ),
              OutlinedButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(l10n.entryRemove),
              ),
              IconButton(
                tooltip: l10n.entryMoveUp,
                onPressed: onMoveUp,
                icon: const Icon(Icons.arrow_upward),
              ),
              IconButton(
                tooltip: l10n.entryMoveDown,
                onPressed: onMoveDown,
                icon: const Icon(Icons.arrow_downward),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
