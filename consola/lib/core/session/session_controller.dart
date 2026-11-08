import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/network/api_client.dart';
import 'package:vecinal_consola/core/session/auth_api.dart';
import 'package:vecinal_consola/core/session/firebase_web_verifier.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';
import 'package:vecinal_consola/core/time/clock.dart';

/// Why the console is on the sign-in page.
enum SignOutReason { signedOut, inactivity, expired, notOperational }

sealed class ConsoleSession {
  const ConsoleSession();
}

final class SignedOut extends ConsoleSession {
  const SignedOut([this.reason]);

  final SignOutReason? reason;
}

final class SignedIn extends ConsoleSession {
  const SignedIn(this.user, {this.demo = false});

  final Operator user;

  /// Seeded account of `CONSOLE_DATA=demo`.
  final bool demo;
}

final authApiProvider = Provider<AuthApi>(
  (ref) => AuthApi(createApiClient(ref.watch(consoleEnvironmentProvider))),
);

final phoneVerifierProvider = Provider<FirebaseWebVerifier?>(
  (ref) => ref.watch(consoleEnvironmentProvider).phoneAuthWithFirebase
      ? FirebaseWebVerifier()
      : null,
);

final sessionProvider = NotifierProvider<SessionController, ConsoleSession>(SessionController.new);

/// Person of the open session, or null. Data providers watch it, so signing out drops their state.
final currentOperatorProvider = Provider<Operator?>(
  (ref) => switch (ref.watch(sessionProvider)) {
    SignedIn(:final user) => user,
    SignedOut() => null,
  },
);

/// Client of the `/v1` API with the session's bearer token. A 401 ends the session.
final consoleApiProvider = Provider<ConsoleApi>((ref) {
  final session = ref.read(sessionProvider.notifier);
  return ConsoleApi(
    createApiClient(ref.watch(consoleEnvironmentProvider), getToken: session.accessToken),
    onUnauthorized: session.expire,
  );
});

/// Owns the session in memory only: tokens never reach localStorage, sessionStorage, IndexedDB or
/// the cache. Reloading the page signs out, by design (design, section 2).
class SessionController extends Notifier<ConsoleSession> {
  SessionTokens? _tokens;
  Future<String?>? _refreshing;

  @override
  ConsoleSession build() => const SignedOut();

  AuthApi get _api => ref.read(authApiProvider);

  DateTime _now() => ref.read(clockProvider)();

  Future<CodeRequest> requestCode(String phone) {
    final verifier = ref.read(phoneVerifierProvider);
    final normalized = normalizePhone(phone);
    return verifier != null ? verifier.sendCode(normalized) : _api.requestCode(normalized);
  }

  /// Opens the session, or throws [SignInFailure]. Sessions without an operational role are closed
  /// in the API right away: the console is only for operational roles.
  Future<void> verifyCode(String phone, String code) async {
    final verifier = ref.read(phoneVerifierProvider);
    final tokens = verifier != null
        ? await _api.exchangeFirebaseToken(await verifier.tokenFor(code))
        : await _api.verifyCode(normalizePhone(phone), code);
    if (!tokens.user.isOperational) {
      await _api.signOut(tokens.accessToken);
      throw const SignInFailure(SignInProblem.notOperational);
    }
    _tokens = tokens;
    state = SignedIn(tokens.user);
  }

  /// Seeded session of `CONSOLE_DATA=demo`: no API call and no token.
  void enterDemo(OperationalRole role) {
    if (!ref.read(consoleEnvironmentProvider).demoData) return;
    _tokens = null;
    state = SignedIn(demoOperator(role), demo: true);
  }

  /// Access token for the API, renewed a minute before it expires. Null when signed out.
  Future<String?> accessToken() {
    final tokens = _tokens;
    if (tokens == null) return Future.value();
    if (tokens.expiresAt.isAfter(_now().add(const Duration(seconds: 60)))) {
      return Future.value(tokens.accessToken);
    }
    // One refresh at a time: the API rotates the refresh token on every use.
    return _refreshing ??= _refresh(tokens).whenComplete(() => _refreshing = null);
  }

  Future<String?> _refresh(SessionTokens tokens) async {
    final renewed = await _api.refresh(tokens.refreshToken);
    // Signed out (or in again) while the refresh was on its way.
    if (!identical(_tokens, tokens)) return _tokens?.accessToken;
    if (renewed == null) {
      _end(SignOutReason.expired);
      return null;
    }
    if (!renewed.user.isOperational) {
      _end(SignOutReason.notOperational);
      await _api.signOut(renewed.accessToken);
      return null;
    }
    _tokens = renewed;
    final current = state;
    if (current is! SignedIn || current.user != renewed.user) {
      state = SignedIn(renewed.user);
    }
    return renewed.accessToken;
  }

  /// Forgets everything first, then closes the session in the API.
  Future<void> signOut([SignOutReason reason = SignOutReason.signedOut]) async {
    String? token;
    try {
      token = await accessToken().timeout(const Duration(seconds: 5));
    } on Object {
      token = null;
    }
    _end(reason);
    if (token != null) await _api.signOut(token);
  }

  /// The API answered 401: the session is no longer valid.
  void expire() {
    if (state is SignedIn && _tokens != null) _end(SignOutReason.expired);
  }

  void _end(SignOutReason reason) {
    _tokens = null;
    _refreshing = null;
    state = SignedOut(reason);
  }
}
