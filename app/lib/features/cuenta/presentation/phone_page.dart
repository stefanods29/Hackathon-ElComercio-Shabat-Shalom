import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/presentation/code_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de ingreso con teléfono y código (toque: /ingresar).
class PhonePage extends ConsumerStatefulWidget {
  const PhonePage({super.key});

  @override
  ConsumerState<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<PhonePage> {
  final _phoneController = TextEditingController();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    var phone = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.length == 9) phone = '51$phone';
    phone = '+$phone';
    if (!_isValidPeruvianPhone(phone)) {
      setState(() => _error = 'Ingresa un número celular válido.');
      return;
    }

    setState(() {
      _isSending = true;
      _error = null;
    });

    try {
      final request = await ref.read(authRepositoryProvider).requestCode(phone);
      if (!mounted) return;
      await context.push<void>(
        Routes.signInCode,
        extra: CodeArguments(phone, retryAfterSeconds: request.retryAfterSeconds),
      );
    } on TooManyAttempts catch (error) {
      if (mounted) {
        setState(
          () => _error = 'Espera ${error.retryAfterSeconds} segundos antes de pedir otro código.',
        );
      }
    } on AuthFailure catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = 'No se pudo enviar el código. Intenta de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  bool _isValidPeruvianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^519[0-9]{8}$').hasMatch(digits);
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(texts.signInTitle)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(texts.signInWelcome, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(texts.signInSubtitle, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 32),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              autofocus: true,
              decoration: InputDecoration(
                labelText: texts.phoneLabel,
                prefixText: '+51 ',
                errorText: _error,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSending ? null : _sendCode,
                child: _isSending
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(texts.sendCode),
              ),
            ),
            const SizedBox(height: 16),
            Text(texts.privacyNotice, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
