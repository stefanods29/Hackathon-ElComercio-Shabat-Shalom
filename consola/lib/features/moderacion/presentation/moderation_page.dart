import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/network/idempotency.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/features/moderacion/data/moderation_repositories.dart';
import 'package:vecinal_consola/features/moderacion/domain/moderation.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Phase 1 moderation queue: pending first, oldest first, and an audited decision with reason.
class ModerationPage extends ConsumerStatefulWidget {
  const ModerationPage({super.key});

  @override
  ConsumerState<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends ConsumerState<ModerationPage> {
  ModerationState _state = ModerationState.pending;
  final _cases = <ModerationCase>[];
  String? _cursor;
  bool _loading = false;
  bool _loadedOnce = false;
  Object? _error;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    _cases.clear();
    _cursor = null;
    _loadedOnce = false;
    await _load();
  }

  Future<void> _load() async {
    final repository = ref.read(moderationRepositoryProvider);
    if (repository == null || _loading) return;
    final state = _state;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await repository.list(state: state, cursor: _cursor);
      // The filter changed while this page was on its way.
      if (!mounted || state != _state) return;
      setState(() {
        _cases.addAll(page.cases);
        _cursor = page.nextCursor;
        _loadedOnce = true;
        _updatedAt = ref.read(clockProvider)();
      });
    } on Object catch (error) {
      if (mounted && state == _state) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _decide(ModerationCase item) async {
    final decided = await showDialog<ModerationCase>(
      context: context,
      builder: (_) => _DecisionDialog(item: item),
    );
    if (decided == null || !mounted) return;
    setState(() {
      // Resolved cases leave the pending list; in the resolved list they are updated in place.
      final index = _cases.indexWhere((row) => row.id == decided.id);
      if (index < 0) return;
      if (_state == ModerationState.pending) {
        _cases.removeAt(index);
      } else {
        _cases[index] = decided;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    final updatedAt = _updatedAt;
    return ConsolePage(
      title: l10n.moderationTitle,
      subtitle: updatedAt == null ? null : l10n.updatedAt(formatClock(updatedAt)),
      actions: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _reload,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.refresh),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          ChoiceRow<ModerationState>(
            label: l10n.moderationFilter,
            options: ModerationState.values,
            selected: _state,
            labelOf: (state) => state == ModerationState.pending
                ? l10n.moderationPending
                : l10n.moderationResolved,
            onSelected: (state) {
              if (state == _state) return;
              setState(() => _state = state);
              _reload();
            },
          ),
          const SizedBox(height: 16),
          if (error != null) ...[
            ProblemNotice(error: error, onRetry: _load),
            const SizedBox(height: 16),
          ],
          if (_loadedOnce && _cases.isEmpty)
            InfoCard(
              icon: Icons.task_alt,
              title: _state == ModerationState.pending
                  ? l10n.moderationEmptyPending
                  : l10n.moderationEmptyResolved,
            ),
          for (final item in _cases)
            _ModerationCard(
              item: item,
              onDecide: item.state == ModerationState.pending ? () => _decide(item) : null,
            ),
          if (_loading)
            const LoadingIndicator()
          else if (_cursor != null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(onPressed: _load, child: Text(l10n.loadMore)),
            ),
        ],
      ),
    );
  }
}

String contentTypeLabel(AppLocalizations l10n, String code) => switch (code) {
  'publicacion' => l10n.contentPost,
  'resena' => l10n.contentReview,
  'servicio' => l10n.contentService,
  'foto' => l10n.contentPhoto,
  'proveedor' => l10n.contentProvider,
  _ => code,
};

String reasonCodeLabel(AppLocalizations l10n, String code) => switch (code) {
  'spam' => l10n.reportSpam,
  'ofensivo' => l10n.reportOffensive,
  'informacion_falsa' => l10n.reportFalse,
  'datos_personales' => l10n.reportPersonalData,
  'peligroso' => l10n.reportDangerous,
  'otro' => l10n.reportOther,
  _ => l10n.reportAutomatic(code),
};

String moderationActionLabel(AppLocalizations l10n, ModerationAction action) => switch (action) {
  ModerationAction.publish => l10n.moderationPublish,
  ModerationAction.hide => l10n.moderationHide,
  ModerationAction.restore => l10n.moderationRestore,
  ModerationAction.dismiss => l10n.moderationDismiss,
  ModerationAction.sanction => l10n.moderationSanction,
};

class _ModerationCard extends StatelessWidget {
  const _ModerationCard({required this.item, required this.onDecide});

  final ModerationCase item;
  final VoidCallback? onDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final last = item.lastAction;
    final firstReview = item.firstReviewAt;
    return FocusableCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.moderationCaseTitle(
              contentTypeLabel(l10n, item.contentType),
              reasonCodeLabel(l10n, item.reasonCode),
            ),
            style: textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(l10n.moderationCreated(formatDayAndClock(item.createdAt)), style: textTheme.bodyLarge),
          if (firstReview != null)
            Text(
              l10n.moderationFirstReview(formatDayAndClock(firstReview)),
              style: textTheme.bodyLarge,
            ),
          if (last != null)
            Text(
              l10n.moderationLastAction(moderationActionLabel(l10n, last)),
              style: textTheme.bodyLarge,
            ),
          Text(l10n.moderationContentId(item.contentId), style: textTheme.bodySmall),
          if (onDecide != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onDecide,
              icon: const Icon(Icons.gavel_outlined),
              label: Text(l10n.moderationDecide),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionDialog extends ConsumerStatefulWidget {
  const _DecisionDialog({required this.item});

  final ModerationCase item;

  @override
  ConsumerState<_DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends ConsumerState<_DecisionDialog> {
  final _reason = TextEditingController();
  String _key = newLocalId();
  ModerationAction? _action;
  String? _validation;
  bool _sending = false;
  Object? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context);
    final action = _action;
    final reason = _reason.text.trim();
    final repository = ref.read(moderationRepositoryProvider);
    if (repository == null) return;
    if (action == null) {
      setState(() => _validation = l10n.moderationChooseAction);
      return;
    }
    if (reason.isEmpty) {
      setState(() => _validation = l10n.moderationReasonRequired);
      return;
    }
    setState(() {
      _validation = null;
      _error = null;
      _sending = true;
    });
    try {
      final decided = await repository.decide(
        widget.item.id,
        action: action,
        reason: reason,
        idempotencyKey: _key,
      );
      if (mounted) Navigator.of(context).pop(decided);
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
    final error = _error;
    return AlertDialog(
      title: Text(l10n.moderationDecide),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.moderationCaseTitle(
                  contentTypeLabel(l10n, widget.item.contentType),
                  reasonCodeLabel(l10n, widget.item.reasonCode),
                ),
                style: textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ChoiceRow<ModerationAction>(
                label: l10n.moderationChooseAction,
                options: ModerationAction.values,
                selected: _action,
                labelOf: (action) => moderationActionLabel(l10n, action),
                onSelected: (action) => setState(() {
                  _action = action;
                  // Another decision is another change: it gets its own key.
                  _key = newLocalId();
                }),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _reason,
                enabled: !_sending,
                minLines: 2,
                maxLines: 5,
                maxLength: decisionReasonMaxLength,
                onChanged: (_) => _key = newLocalId(),
                decoration: fieldDecoration(
                  l10n.reasonRequiredLabel,
                  helper: l10n.moderationReasonHelp,
                ),
              ),
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
          onPressed: _sending ? null : _send,
          child: Text(_sending ? l10n.sending : l10n.moderationSend),
        ),
      ],
    );
  }
}
