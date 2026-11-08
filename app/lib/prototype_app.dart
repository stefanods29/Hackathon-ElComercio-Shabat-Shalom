import 'package:flutter/material.dart';
import 'package:vecinal/prototype_router.dart';

/// Skeleton de la app vecinal para pruebas de UI/UX en dispositivo móvil.
///
/// Incluye las pantallas clave del flujo:
/// bienvenida > login por teléfono > código > elegir zona > muro > publicar > cuenta.
class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Vecinal · Prototipo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5FAD),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 16),
          bodyMedium: TextStyle(fontSize: 14),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
      ),
      routerConfig: prototypeRouter,
    );
  }
}
