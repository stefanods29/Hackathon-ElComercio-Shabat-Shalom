import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Pantalla de bienvenida del prototipo Winki. Punto de entrada del flujo.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: width < 380 ? 20 : 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: WinkiLogo(size: width < 380 ? 64 : 76, withText: true),
                  ),
                  const SizedBox(height: 40),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(kRadiusCardLarge),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.waving_hand_outlined, color: colors.primary, size: 30),
                          const SizedBox(height: 20),
                          Text(
                            l10n.protoWelcomeHeading,
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: kTextColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(l10n.protoTagline, style: Theme.of(context).textTheme.bodyLarge),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  ProtoButton(
                    key: const ValueKey<String>('welcome-sign-in'),
                    text: l10n.signInTitle,
                    icon: Icons.arrow_forward,
                    onPressed: () => context.go('/ingresar'),
                    fullWidth: true,
                  ),
                  const SizedBox(height: 8),
                  ProtoButton(
                    key: const ValueKey<String>('welcome-visitor'),
                    text: l10n.protoEnterAsVisitor,
                    icon: Icons.person_outline,
                    onPressed: () => context.go('/elegir-zona'),
                    fullWidth: true,
                    secondary: true,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.connectsNeighbors,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
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
