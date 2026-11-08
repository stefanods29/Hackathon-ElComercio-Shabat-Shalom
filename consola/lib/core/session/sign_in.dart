/// What the code request answered: when the code can be asked again and when it expires.
class CodeRequest {
  const CodeRequest({required this.retryAfterSeconds, required this.expiresInSeconds});

  final int retryAfterSeconds;
  final int expiresInSeconds;
}

/// Why signing in did not work. The sign-in page explains each one with its own text.
enum SignInProblem {
  invalidCode,
  tooManyAttempts,
  invalidPhone,
  sendFailed,
  checkFailed,
  quotaExceeded,
  network,
  notOperational,
}

class SignInFailure implements Exception {
  const SignInFailure(this.problem, {this.retryAfterSeconds});

  final SignInProblem problem;
  final int? retryAfterSeconds;

  @override
  String toString() => 'SignInFailure(${problem.name})';
}

/// International format for the API: `+51` is added to a nine-digit Peruvian mobile number.
String normalizePhone(String typed) {
  final digits = typed.replaceAll(RegExp(r'[^0-9]'), '');
  if (typed.trim().startsWith('+')) return '+$digits';
  if (digits.length == 9 && digits.startsWith('9')) return '+51$digits';
  return '+$digits';
}

/// Shows only the last two digits, as the API logs do.
String maskPhone(String phone) {
  final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 4) return '••••';
  return '•••• ••• •${digits.substring(digits.length - 2)}';
}
