import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';

/// Pantalla de ingreso del código de 6 dígitos.
class CodeScreen extends StatefulWidget {
  const CodeScreen({super.key});

  @override
  State<CodeScreen> createState() => _CodeScreenState();
}

class _CodeScreenState extends State<CodeScreen> {
  final codeController = TextEditingController();
  int secondsLeft = 30;
  String? error;

  @override
  void dispose() {
    codeController.dispose();
    super.dispose();
  }

  void _verify() {
    if (codeController.text.trim() == '123456') {
      context.go('/elegir-zona');
    } else {
      setState(() => error = 'El código no es correcto o ya venció.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Código de verificación', style: TextStyle(color: kTextColor)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingresa el código',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se envió un código de 6 dígitos a tu número.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 52,
                      height: 60,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: kSurfaceColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: index < codeController.text.length ? kPrimaryColor : Colors.grey.shade300, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          index < codeController.text.length
                              ? codeController.text[index]
                              : '',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  autofocus: true,
                  style: const TextStyle(fontSize: 22, color: kTextColor),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    hintText: '000000',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: kErrorColor, fontSize: 14)),
                ],
                const SizedBox(height: 28),
                ProtoButton(
                  text: 'Verificar código',
                  icon: Icons.verified,
                  onPressed: _verify,
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('¿No recibes el código? ', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                    Text(
                      'Reenviar en ${secondsLeft}s',
                      style: const TextStyle(color: kPrimaryColor, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProtoButton(
                  text: 'Volver',
                  icon: Icons.arrow_back,
                  onPressed: () => context.go('/ingresar'),
                  fullWidth: true,
                  secondary: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
