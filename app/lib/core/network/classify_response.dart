import 'package:dio/dio.dart';
import 'package:vecinal/core/network/problem_details.dart';
import 'package:vecinal/core/submissions/submission_status.dart';

/// Maps the HTTP response of a submission to the state machine (contract in `contracts/`).
AttemptResult classifyResponse(int? status, Object? body) {
  if (status == null) {
    return const TransientFailure('La respuesta no trajo código HTTP.');
  }
  if (status >= 200 && status < 300) {
    return const Accepted();
  }
  if (!isDefinitiveRejectionStatus(status)) {
    return TransientFailure('El servidor respondió $status; se reintentará.');
  }
  final problem = body is Map<String, Object?>
      ? ProblemDetails.fromJson(body, httpStatus: status)
      : ProblemDetails(status: status, title: 'Error $status', code: 'desconocido');
  return Rejected(
    RejectionReason(code: problem.code, title: problem.title, detail: problem.detail),
  );
}

/// Network errors (no response from the server) are always retried.
AttemptResult classifyError(DioException error) {
  final response = error.response;
  if (response == null) {
    return TransientFailure('Sin conexión con el servidor (${error.type.name}).');
  }
  return classifyResponse(response.statusCode, response.data);
}
