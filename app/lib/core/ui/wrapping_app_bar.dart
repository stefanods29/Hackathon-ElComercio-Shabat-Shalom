import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gives a long title room for two lines at the user's text size.
///
/// [actionsWidth] is the room the [actions] take, so the title wraps before reaching them.
AppBar wrappingAppBar(
  BuildContext context,
  String title, {
  List<Widget>? actions,
  double actionsWidth = 0,
  PreferredSizeWidget? bottom,
}) {
  final theme = Theme.of(context);
  final style = theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge!;
  final scaler = MediaQuery.textScalerOf(context);
  final spacing = theme.appBarTheme.titleSpacing ?? NavigationToolbar.kMiddleSpacing;
  final hasLeading = ModalRoute.of(context)?.impliesAppBarDismissal == true;
  final leadingWidth = hasLeading ? 56.0 : 0.0;
  final painter =
      TextPainter(
        text: TextSpan(text: title, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 2,
      )..layout(
        maxWidth: math.max(
          0,
          MediaQuery.sizeOf(context).width - leadingWidth - 2 * spacing - actionsWidth,
        ),
      );
  final height = math.max(theme.appBarTheme.toolbarHeight ?? kToolbarHeight, painter.height + 8);
  painter.dispose();
  return AppBar(
    toolbarHeight: height,
    title: Text(title, maxLines: 2, overflow: TextOverflow.clip),
    actions: actions,
    bottom: bottom,
  );
}
