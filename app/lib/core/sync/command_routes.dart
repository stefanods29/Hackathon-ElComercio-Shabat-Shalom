import 'package:vecinal/core/submissions/submission.dart';

/// HTTP method and path that receive a queued command (contract in `contracts/openapi.yaml`).
typedef CommandRoute = ({String method, String path, bool sendsBody});

/// Maps each kind of command to its API route. Every route requires `Idempotency-Key`.
CommandRoute commandRoute(SubmissionKind kind, String resourceId) => switch (kind) {
  SubmissionKind.publish => (method: 'POST', path: '/v1/publicaciones', sendsBody: true),
  SubmissionKind.takeFavor => (
    method: 'POST',
    path: '/v1/publicaciones/$resourceId/tomar',
    sendsBody: true,
  ),
  SubmissionKind.publishService => (method: 'POST', path: '/v1/servicios', sendsBody: true),
  SubmissionKind.updateService => (
    method: 'PUT',
    path: '/v1/servicios/$resourceId',
    sendsBody: true,
  ),
  SubmissionKind.withdrawService => (
    method: 'DELETE',
    path: '/v1/servicios/$resourceId',
    sendsBody: false,
  ),
  SubmissionKind.upsertProvider => (method: 'PUT', path: '/v1/yo/proveedor', sendsBody: true),
  SubmissionKind.writeReview => (method: 'POST', path: '/v1/resenas', sendsBody: true),
  SubmissionKind.giveEndorsement => (
    method: 'POST',
    path: '/v1/servicios/$resourceId/visto-bueno',
    sendsBody: false,
  ),
  SubmissionKind.withdrawEndorsement => (
    method: 'DELETE',
    path: '/v1/servicios/$resourceId/visto-bueno',
    sendsBody: false,
  ),
  SubmissionKind.report => (method: 'POST', path: '/v1/denuncias', sendsBody: true),
  SubmissionKind.helpRequest => (method: 'POST', path: '/v1/pedidos-ayuda', sendsBody: true),
};
