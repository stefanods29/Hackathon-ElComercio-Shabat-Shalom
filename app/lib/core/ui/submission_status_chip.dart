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
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
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
      // A row instead of Chip: the label wraps at 200 % text and the widget still reports its
      // intrinsic size, which dialogs need.
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: foreground, size: 18),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(color: foreground, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
