import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/core/ui/submission_status_chip.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/features/reputacion/domain/reputation.dart';
import 'package:vecinal/features/reputacion/domain/use_cases.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ReportButton extends StatelessWidget {
  const ReportButton({super.key, required this.content, required this.contentId});
  final ReportedContent content;
  final String contentId;
  @override
  Widget build(BuildContext context) => TextButton.icon(
    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant),
    icon: const Icon(Icons.flag_outlined),
    label: Text(AppLocalizations.of(context).reportAction),
    onPressed: () => showDialog<void>(
      context: context,
      builder: (_) => ReportDialog(content: content, contentId: contentId),
    ),
  );
}

class ReportDialog extends ConsumerStatefulWidget {
  const ReportDialog({super.key, required this.content, required this.contentId});
  final ReportedContent content;
  final String contentId;
  @override
  ConsumerState<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends ConsumerState<ReportDialog> {
  ReportReason _reason = ReportReason.spam;
  final _detail = TextEditingController();
  Submission? _submission;
  bool _busy = false;
  bool _failed = false;
  @override
  void dispose() {
    _detail.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    return AlertDialog(
      scrollable: true,
      title: Text(t.reportTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_submission case final submission?) ...[
              Text(
                submission.status == SubmissionStatus.couldNotComplete
                    ? t.actionFailed
                    : t.reportThanks,
              ),
              SubmissionStatusChip(status: submission.status),
            ] else ...[
              Text(t.reportReason),
              RadioGroup<ReportReason>(
                groupValue: _reason,
                onChanged: (value) {
                  if (!_busy && value != null) {
                    setState(() => _reason = value);
                  }
                },
                child: Column(
                  children: [
                    for (final reason in ReportReason.values)
                      RadioListTile<ReportReason>(
                        title: Text(switch (reason) {
                          ReportReason.spam => t.reportSpam,
                          ReportReason.offensive => t.reportOffensive,
                          ReportReason.falseInformation => t.reportFalse,
                          ReportReason.personalData => t.reportPersonalData,
                          ReportReason.dangerous => t.reportDangerous,
                          ReportReason.other => t.reportOther,
                        }),
                        value: reason,
                        enabled: !_busy,
                      ),
                  ],
                ),
              ),
              TextField(
                controller: _detail,
                maxLength: 500,
                maxLines: 3,
                decoration: InputDecoration(labelText: t.reportDetail),
              ),
              if (_failed) Text(t.actionFailed),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: Text(_submission == null ? t.cancel : t.reportClose),
        ),
        if (_submission == null)
          FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() {
                      _busy = true;
                      _failed = false;
                    });
                    try {
                      final submission = await ReportContent(ref.read(reputationRepositoryProvider))
                          .execute(
                            NewReport(
                              content: widget.content,
                              contentId: widget.contentId,
                              reason: _reason,
                              detail: _detail.text,
                            ),
                          );
                      if (mounted) setState(() => _submission = submission);
                    } catch (_) {
                      if (mounted) setState(() => _failed = true);
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: Text(_busy ? t.loadingAction : t.reportAction),
          ),
      ],
    );
  }
}
