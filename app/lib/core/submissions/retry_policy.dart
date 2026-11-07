import 'dart:math';

/// Exponential backoff with random variation ("full jitter").
///
/// Keeps thousands of phones from retrying at once when the signal comes back (section 5.6).
class RetryPolicy {
  const RetryPolicy({
    this.base = const Duration(seconds: 2),
    this.max = const Duration(minutes: 5),
  });

  final Duration base;
  final Duration max;

  /// Delay before retry number [attempt] (1 = first retry).
  ///
  /// The ceiling grows like this: base, 2×base, 4×base… up to [max]; the actual delay is a
  /// random value between zero and that ceiling.
  Duration delayFor(int attempt, Random random) {
    if (attempt < 1) {
      throw ArgumentError.value(attempt, 'attempt', 'debe ser 1 o mayor');
    }
    final exponent = min(attempt - 1, 20);
    final ceilingMs = min(base.inMilliseconds * pow(2, exponent), max.inMilliseconds).toInt();
    return Duration(milliseconds: random.nextInt(ceilingMs + 1));
  }
}
