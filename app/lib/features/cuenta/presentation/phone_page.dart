import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/vecinal_tokens.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/presentation/code_page.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PhonePage extends ConsumerStatefulWidget {
  const PhonePage({super.key});
  @override
  ConsumerState<PhonePage> createState() => _PhonePageState();
}

class _PhonePageState extends ConsumerState<PhonePage> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSending = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidPeruvianPhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return RegExp(r'^519[0-9]{8}$').hasMatch(digits);
  }

  Future<void> _sendCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    var digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 9) digits = '51$digits';
    final phone = '+$digits';
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
      if (mounted)
        setState(
          () => _error = AppLocalizations.of(context).waitBeforeRetry(error.retryAfterSeconds),
        );
    } catch (_) {
      if (mounted) setState(() => _error = AppLocalizations.of(context).authTryAgainError);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final tokens = context.vecinalTokens;
    return Scaffold(
      appBar: AppBar(title: Text(texts.signInTitle)),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.all(tokens.spaceXl),
                children: [
                  Icon(
                    Icons.phone_android_outlined,
                    size: 40,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(height: tokens.spaceXl),
                  Text(texts.signInWelcome, style: Theme.of(context).textTheme.headlineSmall),
                  SizedBox(height: tokens.spaceSm),
                  Text(texts.signInSubtitle, style: Theme.of(context).textTheme.bodyLarge),
                  SizedBox(height: tokens.space2xl),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    autofocus: true,
                    onFieldSubmitted: (_) => _sendCode(),
                    decoration: InputDecoration(
                      labelText: texts.phoneLabel,
                      prefixText: '+51 ',
                      errorText: _error,
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      return _isValidPeruvianPhone(digits.length == 9 ? '51$digits' : digits)
                          ? null
                          : texts.phoneInvalidError;
                    },
                  ),
                  SizedBox(height: tokens.spaceLg),
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
                  SizedBox(height: tokens.spaceLg),
                  Text(texts.privacyNotice, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
