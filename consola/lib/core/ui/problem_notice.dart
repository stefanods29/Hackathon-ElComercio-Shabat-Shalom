import 'package:flutter/material.dart';
import 'package:vecinal_consola/core/network/api_errors.dart';
import 'package:vecinal_consola/core/network/problem_details.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// What went wrong and what the person can do, from a Problem Details `codigo` or a lost
/// connection (spec: "Errores explicados").
class ProblemExplanation {
  const ProblemExplanation({
    required this.title,
    required this.action,
    this.detail,
    this.code,
    this.fields = const [],
  });

  final String title;
  final String action;
  final String? detail;
  final String? code;
  final List<FieldError> fields;
}

bool isVersionConflict(Object? error) =>
    error is ApiProblem && error.code == 'conflicto_de_version';

ProblemExplanation explainProblem(AppLocalizations l10n, Object error) {
  if (error is ConnectionProblem) {
    return ProblemExplanation(
      title: l10n.problemConnectionTitle,
      action: l10n.problemConnectionAction,
    );
  }
  if (error is ModuleNotAvailable) {
    return ProblemExplanation(title: l10n.moduleUnavailableTitle, action: l10n.moduleUnavailableHint);
  }
  if (error is UnexpectedResponse) {
    return ProblemExplanation(
      title: l10n.problemUnexpectedTitle,
      action: l10n.problemUnexpectedAction,
    );
  }
  if (error is SignInFailure) {
    return ProblemExplanation(title: signInMessage(l10n, error), action: l10n.problemGenericAction);
  }
  if (error is! ApiProblem) {
    return ProblemExplanation(title: l10n.problemUnknownTitle, action: l10n.problemUnknownAction);
  }
  final problem = error.problem;
  final seconds = problem.retryAfterSeconds;
  final (title, action) = switch (problem.code) {
    'conflicto_de_version' => (
      l10n.problemVersionConflictTitle,
      l10n.problemVersionConflictAction,
    ),
    'transicion_invalida' => (
      l10n.problemInvalidTransitionTitle,
      l10n.problemInvalidTransitionAction,
    ),
    'no_autenticado' => (l10n.problemUnauthenticatedTitle, l10n.problemUnauthenticatedAction),
    'prohibido' || 'rol_requerido' || 'nivel_de_confianza_insuficiente' => (
      l10n.problemForbiddenTitle,
      l10n.problemForbiddenAction,
    ),
    'recurso_no_encontrado' => (l10n.problemNotFoundTitle, l10n.problemNotFoundAction),
    'validacion' || 'solicitud_invalida' => (
      l10n.problemValidationTitle,
      l10n.problemValidationAction,
    ),
    'directorio_invalido' => (
      l10n.problemInvalidDirectoryTitle,
      l10n.problemInvalidDirectoryAction,
    ),
    'zona_sin_cobertura' => (l10n.problemNoCoverageTitle, l10n.problemNoCoverageAction),
    'demasiadas_solicitudes' => (
      l10n.problemTooManyTitle,
      seconds != null ? l10n.problemTooManyActionSeconds(seconds) : l10n.problemTooManyAction,
    ),
    'servicio_no_disponible' => (l10n.problemUnavailableTitle, l10n.problemUnavailableAction),
    'idempotency_key_reutilizada' => (l10n.problemKeyReusedTitle, l10n.problemKeyReusedAction),
    'solicitud_en_curso' => (l10n.problemInProgressTitle, l10n.problemInProgressAction),
    _ => (problem.title, l10n.problemGenericAction),
  };
  return ProblemExplanation(
    title: title,
    action: action,
    detail: problem.detail,
    code: problem.code,
    fields: problem.fieldErrors,
  );
}

String signInMessage(AppLocalizations l10n, SignInFailure failure) => switch (failure.problem) {
  SignInProblem.invalidCode => l10n.signInInvalidCode,
  SignInProblem.tooManyAttempts => l10n.signInTooManyAttempts(failure.retryAfterSeconds ?? 60),
  SignInProblem.invalidPhone => l10n.signInInvalidPhone,
  SignInProblem.sendFailed => l10n.signInSendFailed,
  SignInProblem.checkFailed => l10n.signInCheckFailed,
  SignInProblem.quotaExceeded => l10n.signInQuotaExceeded,
  SignInProblem.network => l10n.signInNetwork,
  SignInProblem.notOperational => l10n.signInNotOperational,
};

/// A card with the explanation, announced to screen readers when it appears.
class ProblemNotice extends StatelessWidget {
  const ProblemNotice({super.key, required this.error, this.onRetry, this.retryLabel});

  final Object error;
  final VoidCallback? onRetry;
  final String? retryLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final explanation = explainProblem(l10n, error);
    final color = scheme.onErrorContainer;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Card(
        color: scheme.errorContainer,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.error_outline, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      explanation.title,
                      style: textTheme.titleMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(explanation.action, style: textTheme.bodyLarge?.copyWith(color: color)),
              if (explanation.detail case final detail?) ...[
                const SizedBox(height: 4),
                Text(detail, style: textTheme.bodyMedium?.copyWith(color: color)),
              ],
              for (final field in explanation.fields.take(5))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.problemField(field.field, field.message),
                    style: textTheme.bodyMedium?.copyWith(color: color),
                  ),
                ),
              if (explanation.code case final code?) ...[
                const SizedBox(height: 8),
                Text(l10n.problemCode(code), style: textTheme.bodySmall?.copyWith(color: color)),
              ],
              if (onRetry != null) ...[
                const SizedBox(height: 12),
                FilledButton.tonal(onPressed: onRetry, child: Text(retryLabel ?? l10n.retry)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
