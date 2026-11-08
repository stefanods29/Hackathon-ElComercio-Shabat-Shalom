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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.protoEnterCode, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  Text(l10n.verifyCodeSubtitle, style: Theme.of(context).textTheme.bodyLarge),
                  const SizedBox(height: 24),
                  Semantics(
                    label: l10n.codeLabel,
                    child: ExcludeSemantics(
                      child: Row(
                        children: [
                          for (var index = 0; index < 6; index++) ...[
                            if (index > 0) const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                constraints: const BoxConstraints(minHeight: 56),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: kSurfaceColor,
                                  borderRadius: BorderRadius.circular(kRadiusMedium),
                                  border: Border.all(
                                    color: index < _codeController.text.length
                                        ? kPrimaryColor
                                        : kBorderColor,
                                    width: index < _codeController.text.length ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  index < _codeController.text.length
                                      ? _codeController.text[index]
                                      : '',
                                  style: Theme.of(context).textTheme.headlineMedium,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const ValueKey<String>('prototype-code-input'),
                    controller: _codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 6,
                    autofocus: true,
                    textAlign: TextAlign.center,
                    onChanged: (_) => setState(() => _invalidCode = false),
                    onSubmitted: (_) => _verify(),
                    decoration: InputDecoration(
                      labelText: l10n.codeLabel,
                      hintText: '000000',
                      errorText: _invalidCode ? l10n.protoInvalidCode : null,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                  ProtoButton(
                    key: const ValueKey<String>('prototype-verify-code'),
                    text: l10n.verifyCodeButton,
                    icon: Icons.verified_outlined,
                    onPressed: _verify,
                    fullWidth: true,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.protoResendIn(_secondsLeft),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.go(ProtoRoutes.login),
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
