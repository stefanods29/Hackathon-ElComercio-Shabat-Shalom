import 'package:flutter/widgets.dart';

/// Inserts a vertical gap between the children of a scrolling list, so screens never look
/// cramped (a `Column` uses its own `spacing`).
List<Widget> spaced(List<Widget> children, {double gap = 14}) => [
  for (var i = 0; i < children.length; i++) ...[if (i > 0) SizedBox(height: gap), children[i]],
];
