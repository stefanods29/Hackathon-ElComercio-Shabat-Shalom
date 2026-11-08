import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
      appBar: AppBar(title: const Text('Código de verificación')),
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
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'Se envió un código de 6 dígitos a tu número.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(6, (index) {
                    return Container(
                      width: 48,
                      height: 56,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Center(
                        child: Text(
                          index < codeController.text.length ? codeController.text[index] : '',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
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
                  style: const TextStyle(fontSize: 20),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '000000',
                    border: InputBorder.none,
                    counterText: '',
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: const TextStyle(color: Colors.red, fontSize: 14)),
                ],
                const SizedBox(height: 24),
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
                    const Text('¿No recibes el código? '),
                    Text(
                      'Reenviar en ${secondsLeft}s',
                      style: const TextStyle(color: Color(0xFF0B5FAD), fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.go('/ingresar'), child: const Text('Volver')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
