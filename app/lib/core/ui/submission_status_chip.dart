import 'package:flutter/material.dart';
import 'package:vecinal/core/submissions/submission_status.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Always shows whether an action is saved on the phone, sent or rejected (section 3.4).
///
/// Icon and text together: color is never the only signal.
class SubmissionStatusChip extends StatelessWidget {
  const SubmissionStatusChip({super.key, required this.status});

  final SubmissionStatus status;

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final (icon, label, background, foreground) = switch (status) {
      SubmissionStatus.savedOnPhone => (
        Icons.phone_android,
        texts.statusSavedOnPhone,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      SubmissionStatus.sent => (
        Icons.cloud_done_outlined,
        texts.statusSent,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      SubmissionStatus.couldNotComplete => (
        Icons.error_outline,
        texts.statusCouldNotComplete,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, constraints) => Chip(
          avatar: Icon(icon, color: foreground, size: 20),
          label: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: constraints.hasBoundedWidth
                  ? (constraints.maxWidth > 64 ? constraints.maxWidth - 64 : 0)
                  : double.infinity,
            ),
            child: Text(label),
          ),
          labelStyle: TextStyle(color: foreground, fontWeight: FontWeight.w600),
          backgroundColor: background,
          side: BorderSide.none,
        ),
      ),
    );
  }
}
