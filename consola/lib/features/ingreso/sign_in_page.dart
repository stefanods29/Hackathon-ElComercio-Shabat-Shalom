import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/config/console_environment.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/operator.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/session/sign_in.dart';
import 'package:vecinal_consola/core/theme/console_theme.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Same OTP as the app (API or Firebase). With `CONSOLE_DATA=demo` it offers seeded accounts only,
/// so demo data never mixes with a real session.
class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionProvider);
    final reason = session is SignedOut ? session.reason : null;
    final demo = ref.watch(demoDataProvider);
    return Scaffold(
      body: SafeArea(
        child: CenteredMessage(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(l10n.signInTitle, style: textTheme.headlineSmall),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.signInIntro, style: textTheme.bodyLarge),
                  if (reason case final shown? when shown != SignOutReason.signedOut) ...[
                    const SizedBox(height: 16),
                    _ReasonNotice(reason: shown),
                  ],
                  const SizedBox(height: 24),
                  if (demo) const _DemoSignIn() else const _OtpSignIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonNotice extends StatelessWidget {
  const _ReasonNotice({required this.reason});

  final SignOutReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final (icon, text) = switch (reason) {
      SignOutReason.inactivity => (Icons.timer_off_outlined, l10n.signedOutInactivity),
      SignOutReason.expired => (Icons.lock_clock_outlined, l10n.signedOutExpired),
      SignOutReason.notOperational => (Icons.block, l10n.signInNotOperational),
      SignOutReason.signedOut => (Icons.logout, l10n.signedOutManually),
    };
    return Semantics(
      liveRegion: true,
      child: InfoCard(icon: icon, title: text),
    );
  }
}

class _OtpSignIn extends ConsumerStatefulWidget {
  const _OtpSignIn();

  @override
  ConsumerState<_OtpSignIn> createState() => _OtpSignInState();
}

class _OtpSignInState extends ConsumerState<_OtpSignIn> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  bool _codeSent = false;
  bool _busy = false;
  Object? _error;
  String? _fieldError;
  int _resendIn = 0;
  Timer? _countdown;

  @override
  void dispose() {
    _countdown?.cancel();
    _phone.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    setState(() => _resendIn = seconds);
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _resendIn = _resendIn > 0 ? _resendIn - 1 : 0);
      if (_resendIn == 0) timer.cancel();
    });
  }

  Future<void> _sendCode() async {
    final l10n = AppLocalizations.of(context);
    final digits = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 9 || digits.length > 15) {
      setState(() => _fieldError = l10n.signInPhoneInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldError = null;
    });
    try {
      final request = await ref.read(sessionProvider.notifier).requestCode(_phone.text);
      if (!mounted) return;
      setState(() => _codeSent = true);
      _startCountdown(request.retryAfterSeconds);
      _codeFocus.requestFocus();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context);
    final code = _code.text.trim();
    if (!RegExp(r'^[0-9]{4,8}$').hasMatch(code)) {
      setState(() => _fieldError = l10n.signInCodeInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _fieldError = null;
    });
    try {
      await ref.read(sessionProvider.notifier).verifyCode(_phone.text, code);
      // The router leaves this page as soon as the session opens.
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        if (error is SignInFailure && error.problem == SignInProblem.notOperational) {
          _codeSent = false;
          _code.clear();
        }
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changePhone() {
    _countdown?.cancel();
    setState(() {
      _codeSent = false;
      _error = null;
      _fieldError = null;
      _resendIn = 0;
      _code.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final error = _error;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_codeSent) ...[
            TextField(
              controller: _phone,
              enabled: !_busy,
              keyboardType: TextInputType.phone,
              // Nothing to remember in the browser: no autofill or suggestions for the phone.
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9 +]'))],
              decoration: fieldDecoration(
                l10n.signInPhoneLabel,
                hint: l10n.signInPhoneHint,
                helper: l10n.signInPhoneHelper,
                error: _fieldError,
              ),
              onSubmitted: (_) => _busy ? null : _sendCode(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _sendCode,
              child: Text(_busy ? l10n.sending : l10n.signInSendCode),
            ),
          ] else ...[
            Text(l10n.signInCodeSentTo(maskPhone(normalizePhone(_phone.text)))),
            const SizedBox(height: 16),
            TextField(
              controller: _code,
              focusNode: _codeFocus,
              enabled: !_busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              enableSuggestions: false,
              autocorrect: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: fieldDecoration(l10n.signInCodeLabel, error: _fieldError),
              onSubmitted: (_) => _busy ? null : _verify(),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _busy ? null : _verify,
              child: Text(_busy ? l10n.sending : l10n.signInEnter),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                TextButton(
                  onPressed: _busy || _resendIn > 0 ? null : _sendCode,
                  child: Text(
                    _resendIn > 0 ? l10n.signInResendIn(_resendIn) : l10n.signInResend,
                  ),
                ),
                TextButton(onPressed: _busy ? null : _changePhone, child: Text(l10n.signInChangePhone)),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            error is SignInFailure
                ? Semantics(
                    liveRegion: true,
                    child: InfoCard(icon: Icons.error_outline, title: signInMessage(l10n, error)),
                  )
                : ProblemNotice(error: error),
          ],
        ],
      ),
    );
  }
}

class _DemoSignIn extends ConsumerWidget {
  const _DemoSignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        InfoCard(icon: Icons.science_outlined, title: l10n.demoSignInTitle, body: l10n.demoSignInBody),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final role in OperationalRole.values)
              FilledButton.tonal(
                onPressed: () => ref.read(sessionProvider.notifier).enterDemo(role),
                child: Text(l10n.demoEnterAs(roleLabel(l10n, role))),
              ),
          ],
        ),
      ],
    );
  }
}
