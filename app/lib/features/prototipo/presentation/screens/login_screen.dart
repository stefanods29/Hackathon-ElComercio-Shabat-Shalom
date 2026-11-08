import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kSurfaceColor,
        elevation: 0,
        title: const Text('Ingresar', style: TextStyle(color: kTextColor)),
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
                  'Ingresa tu número',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: kTextColor),
                ),
                const SizedBox(height: 8),
                Text(
                  'Te enviaremos un código de 6 dígitos para entrar a la app.',
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: const Text('+51', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: kTextColor)),
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
                Text(
                  'Usaremos tu número solo para que entres a la app.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 24),
                ProtoButton(
                  text: 'Enviar código',
                  icon: Icons.send,
                  onPressed: _sendCode,
                  fullWidth: true,
                ),
                const SizedBox(height: 16),
                ProtoButton(
                  text: 'Volver',
                  icon: Icons.arrow_back,
                  onPressed: () => context.go('/'),
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
