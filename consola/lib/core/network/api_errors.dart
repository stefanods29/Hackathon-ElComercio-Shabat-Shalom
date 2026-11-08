import 'package:vecinal_consola/core/network/problem_details.dart';

/// The API answered with an error. The screens explain it by its `codigo`.
class ApiProblem implements Exception {
  const ApiProblem(this.problem);

  final ProblemDetails problem;

  String get code => problem.code;

  @override
  String toString() => 'ApiProblem(${problem.status} ${problem.code})';
}

/// No answer from the API: offline, blocked by CORS or timed out.
class ConnectionProblem implements Exception {
  const ConnectionProblem(this.kind);

  final String kind;

  @override
  String toString() => 'ConnectionProblem($kind)';
}

/// The API answered with a body that does not follow the contract.
class UnexpectedResponse implements Exception {
  const UnexpectedResponse(this.reason);

  final String reason;

  @override
  String toString() => 'UnexpectedResponse($reason)';
}

/// The module behind a screen is not in the API yet (for example Emergencias, Phase 2, Lot B).
class ModuleNotAvailable implements Exception {
  const ModuleNotAvailable();

  @override
  String toString() => 'ModuleNotAvailable()';
}

/// Shortcut for the demo doubles, which answer like the API.
ApiProblem demoProblem(int status, String code, {String? detail}) => ApiProblem(
  ProblemDetails(status: status, title: 'Error $status', code: code, detail: detail),
);
