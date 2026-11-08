import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de ingreso por teléfono del prototipo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _sendCode() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    context.go('/ingresar/codigo', extra: '+51${_phoneController.text.trim()}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.signInTitle),
        leading: IconButton(
          tooltip: l10n.protoBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(ProtoRoutes.welcome),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: kPrimaryColor.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(kRadiusCardLarge),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.sms_outlined, size: 32, color: kPrimaryColor),
                          const SizedBox(height: 16),
                          Text(
                            l10n.signInWelcome,
                            style: Theme.of(context).textTheme.headlineLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(l10n.signInSubtitle, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _sendCode(),
                    decoration: InputDecoration(labelText: l10n.phoneLabel, prefixText: '+51  '),
                    validator: (value) {
                      final digits = (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                      return RegExp(r'^9[0-9]{8}$').hasMatch(digits)
                          ? null
                          : l10n.phoneInvalidError;
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(l10n.privacyNotice, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 24),
                  ProtoButton(
                    key: const ValueKey<String>('prototype-send-code'),
                    text: l10n.sendCode,
                    icon: Icons.arrow_forward,
                    onPressed: _sendCode,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => context.go(ProtoRoutes.welcome),
                    child: Text(l10n.protoBack),
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
