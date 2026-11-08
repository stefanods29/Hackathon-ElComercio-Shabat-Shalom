import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';

/// A labeled input whose label and validation are exposed to screen readers.
class ProtoTextField extends StatelessWidget {
  const ProtoTextField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.errorText,
    this.maxLength = 120,
    this.maxLines = 1,
    this.onChanged,
    this.textInputAction,
  });

  final String label;
  final String hint;
  final TextEditingController controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final String? errorText;
  final int maxLength;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    maxLength: maxLength,
    maxLines: maxLines,
    onChanged: onChanged,
    textInputAction: textInputAction,
    style: const TextStyle(fontSize: 16, color: kTextColor),
    decoration: InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: kTextColor),
      hintText: hint,
      hintStyle: const TextStyle(color: kTextSecondaryColor),
      errorText: errorText,
      errorMaxLines: 3,
      errorStyle: const TextStyle(color: kErrorColor, fontSize: 14),
    ),
  );
}
