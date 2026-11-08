import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_text_field.dart';

/// Pantalla de inicio de sesión por teléfono (+51 por defecto).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  String? error;

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  void _sendCode() {
    final phone = phoneController.text.trim();
    if (phone.isEmpty || phone.length < 8) {
      setState(() => error = 'Ingresa un número válido de 9 dígitos.');
      return;
    }
    setState(() => error = null);
    context.go('/ingresar/codigo', extra: phone);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ingresar')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Ingresa tu número',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Te enviaremos un código de 6 dígitos para entrar a la app.',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text('+51', style: TextStyle(fontSize: 16)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ProtoTextField(
                        label: 'Teléfono',
                        hint: '987 654 321',
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        errorText: error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Usaremos tu número solo para que entres a la app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  text: 'Enviar código',
                  icon: Icons.send,
                  onPressed: _sendCode,
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                TextButton(onPressed: () => context.go('/'), child: const Text('Volver')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
