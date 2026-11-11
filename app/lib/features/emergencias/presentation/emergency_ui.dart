import 'package:flutter/material.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Visual pieces of the emergency screens (review of 9 November 2026, section 5): one primary
/// action per screen, calls on top in red, notices as one line with an icon and states before
/// explanations. Colors come from the theme roles so the dark theme keeps working.

/// True when the text is large enough that side-by-side pieces should stack.
bool emergencyLargeText(BuildContext context) => MediaQuery.textScalerOf(context).scale(10) > 14;

/// How a one-line notice is colored. The icon and the words carry the meaning, never the color.
enum NoticeTone { info, warning, danger }

/// A notice in one line (or a few at large text): icon and short text on a soft color.
class EmergencyNotice extends StatelessWidget {
  const EmergencyNotice({
    super.key,
    required this.icon,
    required this.text,
    this.tone = NoticeTone.warning,
    this.liveRegion = false,
  });

  final IconData icon;
  final String text;
  final NoticeTone tone;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      NoticeTone.info => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      NoticeTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      NoticeTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Semantics(
      liveRegion: liveRegion,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(18)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(child: Icon(icon, color: foreground, size: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(text, style: TextStyle(color: foreground, fontSize: 15, height: 1.4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round soft badge behind an icon, as in the cards of the dashboard and the resources.
class EmergencyIconBadge extends StatelessWidget {
  const EmergencyIconBadge({
    super.key,
    required this.icon,
    this.background,
    this.foreground,
    this.size = 48,
  });

  final IconData icon;
  final Color? background;
  final Color? foreground;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? scheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: size * 0.52, color: foreground ?? scheme.onPrimaryContainer),
      ),
    );
  }
}

/// A small pill with an icon and a short state ("Hace 20 min", "Sin verificar").
class EmergencyPill extends StatelessWidget {
  const EmergencyPill({super.key, required this.text, this.icon, this.background, this.foreground});

  final String text;
  final IconData? icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = foreground ?? scheme.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              ExcludeSemantics(child: Icon(icon, size: 18, color: fg)),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                text,
                style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft colors of the pills by meaning. In the dark theme every pill sits on the same neutral
/// surface and only keeps its icon and words, like the rest of the app.
({Color background, Color foreground}) pillColors(ColorScheme scheme, NoticeTone? tone) {
  if (scheme.brightness == Brightness.dark) {
    return (
      background: scheme.surfaceContainerHigh,
      foreground: switch (tone) {
        NoticeTone.warning => scheme.tertiary,
        NoticeTone.danger => scheme.error,
        _ => scheme.onSurface,
      },
    );
  }
  return switch (tone) {
    null => (background: scheme.surfaceContainer, foreground: scheme.onSurface),
    NoticeTone.info => (background: scheme.primaryContainer, foreground: scheme.onPrimaryContainer),
    NoticeTone.warning => (
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
    ),
    NoticeTone.danger => (background: scheme.errorContainer, foreground: scheme.onErrorContainer),
  };
}

/// A white card that is also a button (tiles, needs, own requests): soft shadow in light, a
/// hairline in dark, and calm colors when it is not available.
ButtonStyle emergencyCardStyle(
  ColorScheme scheme, {
  required Size minimumSize,
  required EdgeInsetsGeometry padding,
  AlignmentGeometry alignment = Alignment.topLeft,
  bool enabled = true,
}) {
  final light = scheme.brightness == Brightness.light;
  return FilledButton.styleFrom(
    minimumSize: minimumSize,
    padding: padding,
    alignment: alignment,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AccessibleTheme.radiusCard),
      side: light ? BorderSide.none : BorderSide(color: AccessibleTheme.hairline(scheme)),
    ),
    elevation: enabled && light ? 3 : 0,
    shadowColor: const Color(0xFF64748B).withValues(alpha: 0.35),
    backgroundColor: light ? Colors.white : scheme.surface,
    foregroundColor: scheme.onSurface,
    disabledBackgroundColor: scheme.surfaceContainerHigh,
    disabledForegroundColor: scheme.onSurfaceVariant,
  );
}

/// The one primary action of a screen: big, teal, with a subtitle and a chevron.
class EmergencyPrimaryButton extends StatelessWidget {
  const EmergencyPrimaryButton({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final light = scheme.brightness == Brightness.light;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 88),
        padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
        alignment: Alignment.centerLeft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: onPressed != null && light ? 5 : 0,
        shadowColor: scheme.primary.withValues(alpha: 0.45),
        backgroundColor: AccessibleTheme.action(scheme),
        foregroundColor: AccessibleTheme.onAction(scheme),
        disabledBackgroundColor: scheme.surfaceContainerHighest,
        disabledForegroundColor: scheme.onSurfaceVariant,
      ),
      child: Row(
        children: [
          Icon(icon, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.15),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 30),
        ],
      ),
    );
  }
}

/// A secondary access of the dashboard: a soft white tile with an icon badge and a short label.
class EmergencyActionTile extends StatelessWidget {
  const EmergencyActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.badge,
    this.onPressed,
  });

  final IconData icon;
  final String label;
  final String? badge;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    return FilledButton(
      onPressed: onPressed,
      style: emergencyCardStyle(
        scheme,
        minimumSize: const Size(48, 120),
        padding: const EdgeInsets.all(16),
        enabled: enabled,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmergencyIconBadge(
            icon: icon,
            background: enabled ? null : scheme.surfaceContainerHighest,
            foreground: enabled ? null : scheme.onSurfaceVariant,
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.25),
          ),
          // Under the label it has the whole width, so it never breaks a word on a small phone.
          if (badge != null) ...[
            const SizedBox(height: 8),
            EmergencyPill(
              text: badge!,
              background: scheme.secondaryContainer,
              foreground: scheme.onSecondaryContainer,
            ),
          ],
        ],
      ),
    );
  }
}

/// Lays tiles out two per row; with large text, one per row so nothing is cut.
class EmergencyTileGrid extends StatelessWidget {
  const EmergencyTileGrid({super.key, required this.children, this.gap = 12});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final large = emergencyLargeText(context);
    if (large) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap,
        children: children,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: gap,
      children: [
        for (var i = 0; i < children.length; i += 2)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: gap,
              children: [
                Expanded(child: children[i]),
                Expanded(
                  child: i + 1 < children.length ? children[i + 1] : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Icon of each need, shared by the needs grid, the request card and "Mi pedido".
IconData needIcon(EmergencyNeed need) => switch (need) {
  EmergencyNeed.water => Icons.water_drop_outlined,
  EmergencyNeed.food => Icons.restaurant_outlined,
  EmergencyNeed.medicine => Icons.medication_outlined,
  EmergencyNeed.transport => Icons.directions_bus_outlined,
  EmergencyNeed.shelter => Icons.night_shelter_outlined,
  EmergencyNeed.other => Icons.help_outline,
};

/// Icon of a need of the zone board ("agua", "traslado"…), as in the needs grid.
IconData demandIcon(String need) => switch (need) {
  'agua' => Icons.water_drop_outlined,
  'alimentos' => Icons.restaurant_outlined,
  'medicamentos' => Icons.medication_outlined,
  'traslado' => Icons.directions_bus_outlined,
  'albergue' => Icons.night_shelter_outlined,
  'punto_encuentro' => Icons.groups_outlined,
  _ => Icons.help_outline,
};

/// The kind of resource that answers a need of the zone board; transport has none.
ResourceKind? resourceKindForDemand(String need) => switch (need) {
  'agua' => ResourceKind.water,
  'alimentos' => ResourceKind.food,
  'medicamentos' => ResourceKind.medicine,
  'albergue' => ResourceKind.shelter,
  'punto_encuentro' => ResourceKind.meetingPoint,
  _ => null,
};

/// "hace 3 horas" → "Hace 3 horas", to open a line or a pill.
String sentenceCase(String text) =>
    text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Icon and soft colors of each kind of resource, so the list reads at a glance.
({IconData icon, Color background, Color foreground}) resourceStyle(
  ColorScheme scheme,
  ResourceKind kind,
) {
  final icon = switch (kind) {
    ResourceKind.water => Icons.water_drop_outlined,
    ResourceKind.food => Icons.restaurant_outlined,
    ResourceKind.medicine => Icons.medication_outlined,
    ResourceKind.shelter => Icons.night_shelter_outlined,
    ResourceKind.meetingPoint => Icons.groups_outlined,
    ResourceKind.other => Icons.inventory_2_outlined,
  };
  if (scheme.brightness == Brightness.dark) {
    return (icon: icon, background: scheme.surfaceContainerHigh, foreground: scheme.primary);
  }
  final (background, foreground) = switch (kind) {
    ResourceKind.water => (scheme.primaryContainer, scheme.onPrimaryContainer),
    ResourceKind.food => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
    ResourceKind.medicine => (scheme.errorContainer, scheme.onErrorContainer),
    ResourceKind.shelter => (scheme.secondaryContainer, scheme.onSecondaryContainer),
    ResourceKind.meetingPoint => (scheme.primaryContainer, scheme.onPrimaryContainer),
    ResourceKind.other => (scheme.surfaceContainerHigh, scheme.onSurface),
  };
  return (icon: icon, background: background, foreground: foreground);
}

/// Short name of a national number for the call buttons. Unknown numbers keep their full name.
String emergencyShortName(AppLocalizations t, {required String label, required String number}) =>
    switch (number.replaceAll(' ', '')) {
      '116' => t.emergencyShortFirefighters,
      '105' => t.emergencyShortPolice,
      '106' => t.emergencyShortHealth,
      _ => label,
    };

/// Colors of the call strip and its buttons: red is used only to call.
({Color strip, Color onStrip, Color button, Color onButton}) callColors(ColorScheme scheme) => (
  strip: scheme.errorContainer,
  onStrip: scheme.onErrorContainer,
  button: scheme.error,
  onButton: scheme.onError,
);

/// One red call button: the number big and the short name under it, or both in one line when
/// the buttons are stacked ([horizontal]). Neither the number nor the name ever breaks mid-word.
class EmergencyCallButton extends StatelessWidget {
  const EmergencyCallButton({
    super.key,
    required this.number,
    required this.name,
    required this.semanticLabel,
    required this.onPressed,
    this.horizontal = false,
  });

  final String number;
  final String name;
  final String semanticLabel;
  final VoidCallback onPressed;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = callColors(Theme.of(context).colorScheme);
    final light = Theme.of(context).brightness == Brightness.light;
    const numberStyle = TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.1);
    final content = horizontal
        ? Row(
            children: [
              const Icon(Icons.phone, size: 24),
              const SizedBox(width: 12),
              Text(number, softWrap: false, style: numberStyle),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // A number must never break ("11 / 6"): on a narrow phone it shrinks a little.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 22),
                    const SizedBox(width: 6),
                    Text(number, softWrap: false, style: numberStyle),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              // Nor the name ("Bombero / s"): it shrinks instead of cutting the word.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  name,
                  maxLines: 1,
                  softWrap: false,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, height: 1.2),
                ),
              ),
            ],
          );
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        minimumSize: Size(48, horizontal ? 60 : 72),
        padding: horizontal
            ? const EdgeInsets.symmetric(horizontal: 18, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        alignment: horizontal ? Alignment.centerLeft : Alignment.center,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: colors.button,
        foregroundColor: colors.onButton,
        elevation: light ? 3 : 0,
        shadowColor: colors.button.withValues(alpha: 0.45),
      ),
      // The button keeps its tap action; the screen reader hears the full name and the number.
      child: Semantics(label: semanticLabel, excludeSemantics: true, child: content),
    );
  }
}

/// Three call buttons side by side while each one has room for its name at the user's text size;
/// otherwise one per row, with the number and the name in the same line.
class EmergencyCallButtons extends StatelessWidget {
  const EmergencyCallButtons({super.key, required this.buttons});

  /// (number, short name, label for the screen reader, action).
  final List<(String, String, String, VoidCallback)> buttons;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = buttons.length;
        final each = (constraints.maxWidth - _gap * (count - 1)) / count;
        final longest = buttons.fold<int>(0, (m, b) => b.$2.length > m ? b.$2.length : m);
        // Room for the longest short name ("Bomberos") in bold at this text size, plus padding.
        final stacked = each < (longest * 9.5 + 22) * scale;
        final widgets = [
          for (final (number, name, label, action) in buttons)
            EmergencyCallButton(
              number: number,
              name: name,
              semanticLabel: label,
              onPressed: action,
              horizontal: stacked,
            ),
        ];
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: widgets,
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: _gap,
            children: [for (final widget in widgets) Expanded(child: widget)],
          ),
        );
      },
    );
  }
}

/// A timeline step of "Mi pedido".
enum TimelineState { done, current, pending }

class EmergencyTimelineStep extends StatelessWidget {
  const EmergencyTimelineStep({
    super.key,
    required this.label,
    required this.state,
    this.time,
    this.detail,
    this.isLast = false,
  });

  final String label;
  final TimelineState state;
  final String? time;
  final String? detail;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final accent = AccessibleTheme.action(scheme);
    final pending = state == TimelineState.pending;
    final stateWord = switch (state) {
      TimelineState.done => t.emergencyStepDone,
      TimelineState.current => t.emergencyStepCurrent,
      TimelineState.pending => t.emergencyStepPending,
    };
    final marker = switch (state) {
      TimelineState.done => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
        child: Icon(Icons.check, size: 18, color: AccessibleTheme.onAction(scheme)),
      ),
      TimelineState.current => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: scheme.surface,
          shape: BoxShape.circle,
          border: Border.all(color: accent, width: 8),
        ),
      ),
      TimelineState.pending => Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: scheme.outline, width: 2),
        ),
      ),
    };
    return Semantics(
      label: [label, ?time, ?detail, stateWord].join(', '),
      excludeSemantics: true,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 28,
              child: Column(
                children: [
                  marker,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 3,
                        color: state == TimelineState.done ? accent : scheme.outlineVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: state == TimelineState.current
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              color: pending ? scheme.onSurfaceVariant : scheme.onSurface,
                            ),
                          ),
                        ),
                        if (time != null) ...[
                          const SizedBox(width: 8),
                          Text(time!, style: TextStyle(color: scheme.onSurfaceVariant)),
                        ],
                      ],
                    ),
                    if (detail != null)
                      Text(detail!, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
