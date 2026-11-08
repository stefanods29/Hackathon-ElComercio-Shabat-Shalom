import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de verificación de código de 6 dígitos (/ingresar/codigo).
class CodeArguments {
  const CodeArguments(this.phone, {required this.retryAfterSeconds});
  final String phone;
  final int retryAfterSeconds;
}

class CodePage extends ConsumerStatefulWidget {
  const CodePage({super.key, this.phone = '', this.retryAfterSeconds = 30});
  final String phone;
  final int retryAfterSeconds;

  @override
  ConsumerState<CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<CodePage> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _resendController = ValueNotifier<int>(0);
  bool _isVerifying = false;
  String? _error;
  Timer? _countdown;

  @override
  void initState() {
    super.initState();
    _startResendCountdown(widget.retryAfterSeconds);
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendController.dispose();
    _countdown?.cancel();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final code = _codeController.text.trim();
    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).verifyCode(widget.phone, code);
      if (!mounted) return;
      final authState = ref.read(authStateProvider).value;
      if (authState is NeedsZone) {
        context.go(Routes.chooseZone);
      } else {
        context.go(Routes.home);
      }
    } on TooManyAttempts catch (failure) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = AppLocalizations.of(context).waitBeforeRetry(failure.retryAfterSeconds);
        _startResendCountdown(failure.retryAfterSeconds);
      });
    } on InvalidCode {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = AppLocalizations.of(context).protoInvalidCode;
      });
    } on AuthFailure {
      if (mounted) setState(() => _error = AppLocalizations.of(context).authTryAgainError);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).authTryAgainError);
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _startResendCountdown(int seconds) {
    _countdown?.cancel();
    _resendController.value = seconds;
    if (seconds <= 0) return;
    final deadline = DateTime.now().add(Duration(seconds: seconds));
    _countdown = Timer.periodic(const Duration(seconds: 1), (timer) {
      final left = deadline.difference(DateTime.now()).inMilliseconds;
      _resendController.value = left <= 0 ? 0 : (left / 1000).ceil();
      if (left <= 0) timer.cancel();
    });
  }

  Future<void> _resendCode() async {
    if (_resendController.value > 0) return;
    try {
      final request = await ref.read(authRepositoryProvider).requestCode(widget.phone);
      if (!mounted) return;
      setState(() => _error = null);
      _startResendCountdown(request.retryAfterSeconds);
    } on TooManyAttempts catch (failure) {
      if (mounted) _startResendCountdown(failure.retryAfterSeconds);
    } on AuthFailure {
      if (mounted) setState(() => _error = AppLocalizations.of(context).authTryAgainError);
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).authTryAgainError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(texts.verifyCodeTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '${texts.verifyCodeWelcome} ${widget.phone}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(texts.verifyCodeSubtitle, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: texts.codeLabel,
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) => RegExp(r'^\d{6}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : texts.protoInvalidCode,
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<int>(
                    valueListenable: _resendController,
                    builder: (context, remaining, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isVerifying ? null : _verifyCode,
                          child: _isVerifying
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : Text(texts.verifyCodeButton),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ValueListenableBuilder<int>(
                      valueListenable: _resendController,
                      builder: (context, remaining, child) => TextButton(
                        onPressed: remaining == 0 ? _resendCode : null,
                        child: remaining == 0
                            ? Text(texts.resendCode)
                            : Text('${texts.resendCodeIn} $remaining s'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
