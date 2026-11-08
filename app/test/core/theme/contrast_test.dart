import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/theme/contrast.dart';

void main() {
  group('contrastRatio', () {
    test('blanco sobre negro alcanza 21:1', () {
      expect(contrastRatio(Colors.white, Colors.black), greaterThanOrEqualTo(21.0));
    });

    test('el orden de los colores no importa', () {
      expect(contrastRatio(Colors.white, Colors.black), contrastRatio(Colors.black, Colors.white));
    });
  });

  void checkTheme(String name, ThemeData theme) {
    final scheme = theme.colorScheme;
    final pairs = <(Color, Color)>[
      (scheme.onSurface, scheme.surface),
      (scheme.onPrimary, scheme.primary),
      (scheme.onPrimaryContainer, scheme.primaryContainer),
      (scheme.onSecondaryContainer, scheme.secondaryContainer),
      (scheme.onTertiaryContainer, scheme.tertiaryContainer),
      (scheme.onErrorContainer, scheme.errorContainer),
    ];

    test('$name: todos los pares texto/fondo alcanzan al menos 4,5:1', () {
      for (final (fg, bg) in pairs) {
        expect(
          contrastRatio(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$fg sobre $bg no alcanza 4,5:1',
        );
      }
    });

    test('$name: outline sobre surface alcanza al menos 3:1', () {
      expect(
        contrastRatio(scheme.outline, scheme.surface),
        greaterThanOrEqualTo(3.0),
        reason: 'outline sobre surface no alcanza 3:1',
      );
    });
  }

  group('AccessibleTheme light', () {
    checkTheme('light', AccessibleTheme.light());
  });

  group('AccessibleTheme dark', () {
    final theme = AccessibleTheme.dark();
    checkTheme('dark', theme);

    test('texto secundario, estrellas y bordes mantienen contraste sobre tarjetas', () {
      final scheme = theme.colorScheme;
      final surface = scheme.surfaceContainerHigh;
      expect(contrastRatio(scheme.onSurfaceVariant, surface), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(AccessibleTheme.ratingColor(scheme), surface), greaterThanOrEqualTo(3));
      expect(contrastRatio(scheme.outlineVariant, surface), greaterThanOrEqualTo(3));
    });
  });
}
