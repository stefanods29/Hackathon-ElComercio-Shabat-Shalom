import 'package:flutter/material.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/prototype_router.dart';

/// App principal del prototipo con tema accesible y paleta de colores definida.
class PrototypeApp extends StatelessWidget {
  const PrototypeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Winki',
      debugShowCheckedModeBanner: false,
      theme: winkiTheme(),
      routerConfig: prototypeRouter,
    );
  }
}
