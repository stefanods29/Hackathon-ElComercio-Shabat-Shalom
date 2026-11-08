import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

/// Campo de texto con estilo accesible del prototipo.
class ProtoTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? errorText;
  final int maxLength;
  final int? maxLines;

  const ProtoTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.errorText,
    this.maxLength = 120,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: kTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          maxLength: maxLength,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 16, color: kTextColor),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            errorText: errorText,
            errorStyle: const TextStyle(color: kErrorColor, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
