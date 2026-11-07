import 'package:vecinal/core/submissions/submission.dart';
import 'package:vecinal/core/submissions/submission_status.dart';

Submission submissionFromRow(Map<String, Object?> row) {
  final status = SubmissionStatus.values.byName(row['estado'] as String);
  final attempted = row['ultimo_intento_en'] as String?;
  final lastAttemptAt = attempted == null ? null : DateTime.parse(attempted);
  final code = row['motivo_codigo'] as String?;
  return Submission(
    id: row['id'] as String,
    kind: SubmissionKind.values.byName(row['tipo'] as String),
    resourceId: row['recurso_id'] as String,
    idempotencyKey: row['clave_idempotencia'] as String,
    createdAt: DateTime.parse(row['creado_en'] as String),
    status: status,
    attempts: row['intentos'] as int,
    lastAttemptAt: lastAttemptAt,
    sentAt: status == SubmissionStatus.sent ? lastAttemptAt : null,
    rejectionReason: code == null
        ? null
        : RejectionReason(
            code: code,
            title: row['motivo_titulo'] as String,
            detail: row['motivo_detalle'] as String?,
          ),
  );
}
