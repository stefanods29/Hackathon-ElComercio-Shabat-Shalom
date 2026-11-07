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
class CodePage extends ConsumerStatefulWidget {
  const CodePage({super.key});

  @override
  ConsumerState<CodePage> createState() => _CodePageState();
}

class _CodePageState extends ConsumerState<CodePage> {
  final _codeController = TextEditingController();
  final _resendController = ValueNotifier<int>(0);
  bool _isVerifying = false;
  String? _error;
  String _phone = '';

  @override
  void initState() {
    super.initState();
    _phone = ModalRoute.of(context)!.settings.arguments as String? ?? '';
    _resendController.value = 30;
  }

  @override
  void dispose() {
    _codeController.dispose();
    _resendController.dispose();
    super.dispose();
  }

  Future<void> _verifyCode() async {
    final code = _codeController.text.trim();
    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).verifyCode(_phone, code);
      if (!mounted) return;
      final authState = ref.read(authStateProvider).value;
      if (authState is NeedsZone) {
        context.go(Routes.chooseZone);
      } else {
        context.go(Routes.home);
      }
    } on TooManyAttempts catch (error) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error =
            'Demasiados intentos. Prueba de nuevo en ${error.retryAfterSeconds ~/ 60} min.';
        _resendController.value = error.retryAfterSeconds;
        unawaited(_startResendCountdown(error.retryAfterSeconds));
      });
    } on InvalidCode {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = 'El código no es correcto o ya venció.';
      });
    }
  }

  Future<void> _startResendCountdown(int seconds) async {
    for (int i = seconds; i > 0 && mounted; i--) {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) _resendController.value = i;
    }
    if (mounted) _resendController.value = 0;
  }

  Future<void> _resendCode() async {
    if (_resendController.value > 0) return;
    await ref.read(authRepositoryProvider).requestCode(_phone);
    if (!mounted) return;
    setState(() {
      _resendController.value = 30;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final canResend = _resendController.value == 0;

    return Scaffold(
      appBar: AppBar(title: Text(texts.verifyCodeTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${texts.verifyCodeWelcome} $_phone',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              texts.verifyCodeSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextFormField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              autofocus: true,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: texts.codeLabel,
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
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
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 14,
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: canResend ? _resendCode : null,
                child: canResend
                    ? Text(texts.resendCode)
                    : Text('${texts.resendCodeIn} ${_resendController.value} s'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
