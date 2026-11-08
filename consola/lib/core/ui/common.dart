import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/ui/problem_notice.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Frame of every page: a heading (announced as such), an optional line under it and its actions.
class ConsolePage extends StatelessWidget {
  const ConsolePage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.child,
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Semantics(header: true, child: Text(title, style: textTheme.headlineSmall)),
                  if (subtitle case final line?)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(line, style: textTheme.bodyMedium),
                    ),
                ],
              ),
              if (actions.isNotEmpty) Wrap(spacing: 8, runSpacing: 8, children: actions),
            ],
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// A section heading inside a page.
class SectionHeading extends StatelessWidget {
  const SectionHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 8),
    child: Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    ),
  );
}

/// Label above its value: stays readable with text at 200 %.
class LabeledValue extends StatelessWidget {
  const LabeledValue({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.labelLarge),
            Text(value, style: textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}

enum BadgeTone { neutral, warning, danger, success }

/// Icon and text together: color is never the only signal (WCAG 1.4.1).
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.icon,
    required this.label,
    this.tone = BadgeTone.neutral,
  });

  final IconData icon;
  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (tone) {
      BadgeTone.neutral => (scheme.secondaryContainer, scheme.onSecondaryContainer),
      BadgeTone.warning => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      BadgeTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
      BadgeTone.success => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: foreground),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: foreground),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground)),
          ],
        ),
      ),
    );
  }
}

/// A card that opens something: reachable with the keyboard, with a 3 px border while focused.
class FocusableCard extends StatefulWidget {
  const FocusableCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<FocusableCard> createState() => _FocusableCardState();
}

class _FocusableCardState extends State<FocusableCard> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: _focused ? scheme.primary : scheme.outlineVariant,
        width: _focused ? 3 : 1,
      ),
    );
    final content = Padding(padding: const EdgeInsets.all(16), child: widget.child);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: widget.onTap == null
          ? content
          : MergeSemantics(
              child: InkWell(
                onTap: widget.onTap,
                customBorder: shape,
                onFocusChange: (focused) => setState(() => _focused = focused),
                child: content,
              ),
            ),
    );
  }
}

/// Loading, error (explained, with a retry) or the data.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({super.key, required this.value, required this.data, this.onRetry});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => value.when(
    data: data,
    error: (error, _) => CenteredMessage(
      child: ProblemNotice(error: error, onRetry: onRetry),
    ),
    loading: () => const LoadingIndicator(),
  );
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: CircularProgressIndicator(semanticsLabel: AppLocalizations.of(context).loading),
    ),
  );
}

/// A message in the middle of the page, scrollable when the text is large.
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 640), child: child),
    ),
  );
}

/// Plain informational card (an empty list, a missing zone).
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.icon, required this.title, this.body});

  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  if (body case final text?)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(text, style: textTheme.bodyLarge),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen's module is not in the API yet (Phase 2, Lot B): says so instead of inventing data.
class ModuleUnavailable extends StatelessWidget {
  const ModuleUnavailable({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return CenteredMessage(
      child: InfoCard(
        icon: Icons.construction_outlined,
        title: l10n.moduleUnavailableTitle,
        body: '$message\n\n${l10n.moduleUnavailableHint}',
      ),
    );
  }
}

/// Calls [onTick] every [interval] while the browser tab is visible, and once when it shows again.
class PollWhileVisible extends StatefulWidget {
  const PollWhileVisible({
    super.key,
    required this.interval,
    required this.onTick,
    required this.child,
  });

  final Duration interval;
  final VoidCallback onTick;
  final Widget child;

  @override
  State<PollWhileVisible> createState() => _PollWhileVisibleState();
}

class _PollWhileVisibleState extends State<PollWhileVisible> {
  Timer? _timer;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onShow: () {
        widget.onTick();
        _start();
      },
      onHide: _stop,
    );
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.interval, (_) => widget.onTick());
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stop();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Selection among a few options: chips that wrap with large text and expose their state.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T option) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: label,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              ChoiceChip(
                label: Text(labelOf(option)),
                selected: option == selected,
                onSelected: (_) => onSelected(option),
              ),
          ],
        ),
      ],
    ),
  );
}
