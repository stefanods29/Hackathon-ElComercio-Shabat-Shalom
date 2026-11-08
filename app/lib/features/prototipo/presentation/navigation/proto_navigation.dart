import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/l10n/app_localizations.dart';

enum ProtoHomeTab {
  map('mapa'),
  wall('muro'),
  publish('publicar'),
  account('cuenta');

  const ProtoHomeTab(this.queryValue);
  final String queryValue;

  static ProtoHomeTab fromQuery(String? value) =>
      values.firstWhere((tab) => tab.queryValue == value, orElse: () => map);
}

abstract final class ProtoRoutes {
  static const welcome = '/';
  static const mapa = '/mapa';
  static const login = '/ingresar';
  static const code = '/ingresar/codigo';
  static const zone = '/elegir-zona';
  static const publish = '/publicar';
  static const publishForm = '/publicar/:tipo';
  static const toReview = '/por-revisar';
  static const emergency = '/emergencia';
  static const tutorial = '/tutorial';
  static const account = '/cuenta';
  static const pushSettings = '/avisos';
  static const postDetail = '/publicaciones/:id';

  static String home([ProtoHomeTab tab = ProtoHomeTab.map]) => Uri(
    path: mapa,
    queryParameters: tab == ProtoHomeTab.map ? null : {'vista': tab.queryValue},
  ).toString();
}

/// Preserve the source tab, including a fallback for direct links.
abstract final class ProtoNavigation {
  static void open(BuildContext context, String path) {
    final uri = GoRouterState.of(context).uri;
    final source = uri.path == ProtoRoutes.mapa
        ? uri.queryParameters['vista']
        : uri.queryParameters['volver'];
    unawaited(
      context.push<void>(
        Uri(
          path: path,
          queryParameters: {'volver': ProtoHomeTab.fromQuery(source).queryValue},
        ).toString(),
      ),
    );
  }

  static void back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final source = GoRouterState.of(context).uri.queryParameters['volver'];
    context.go(ProtoRoutes.home(ProtoHomeTab.fromQuery(source)));
  }
}

class ProtoBackButton extends StatelessWidget {
  const ProtoBackButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: AppLocalizations.of(context).protoBack,
    icon: const Icon(Icons.arrow_back),
    onPressed: () => ProtoNavigation.back(context),
  );
}
