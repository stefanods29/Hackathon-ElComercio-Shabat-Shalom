import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final _codeController = TextEditingController();
  // Verification and the resend countdown remain prototype placeholders.
  static const _secondsLeft = 30;
  bool _invalidCode = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _verify() {
    if (_codeController.text == '123456') {
      context.go(ProtoRoutes.zone);
    } else {
      setState(() => _invalidCode = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.verifyCodeTitle),
        leading: IconButton(
          tooltip: l10n.protoBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go(ProtoRoutes.login),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.protoEnterCode, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 8),
              Text(l10n.verifyCodeSubtitle),
              const SizedBox(height: 28),
              // The real input below owns semantics; these boxes only mirror it.
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (var index = 0; index < 6; index++) ...[
                      if (index > 0) const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 60),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: kSurfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: index < _codeController.text.length
                                  ? kPrimaryColor
                                  : kTextSecondaryColor,
                              width: 2,
                            ),
                          ),
                          child: Text(
                            index < _codeController.text.length ? _codeController.text[index] : '',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: kTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                key: const ValueKey('prototype-code-input'),
                controller: _codeController,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                maxLength: 6,
                autofocus: true,
                style: const TextStyle(fontSize: 22, color: kTextColor),
                textAlign: TextAlign.center,
                onChanged: (_) => setState(() => _invalidCode = false),
                onSubmitted: (_) => _verify(),
                decoration: InputDecoration(
                  labelText: l10n.codeLabel,
                  hintText: '000000',
                  hintStyle: const TextStyle(color: kTextSecondaryColor),
                  errorText: _invalidCode ? l10n.protoInvalidCode : null,
                  errorMaxLines: 3,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 28),
              ProtoButton(
                text: l10n.verifyCodeButton,
                icon: Icons.verified_outlined,
                onPressed: _verify,
                fullWidth: true,
              ),
              const SizedBox(height: 16),
              Text(l10n.protoResendIn(_secondsLeft), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ProtoButton(
                text: l10n.protoBack,
                icon: Icons.arrow_back,
                onPressed: () => context.go(ProtoRoutes.login),
                fullWidth: true,
                secondary: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
