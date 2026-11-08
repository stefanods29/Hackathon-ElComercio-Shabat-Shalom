import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal_consola/core/router/console_shell.dart';
import 'package:vecinal_consola/core/router/routes.dart';
import 'package:vecinal_consola/core/session/session_controller.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/avisos_urgentes/presentation/urgent_notices_page.dart';
import 'package:vecinal_consola/features/casos/presentation/case_detail_page.dart';
import 'package:vecinal_consola/features/casos/presentation/cases_queue_page.dart';
import 'package:vecinal_consola/features/celdas/presentation/cells_page.dart';
import 'package:vecinal_consola/features/curaduria/presentation/directories_page.dart';
import 'package:vecinal_consola/features/curaduria/presentation/directory_editor_page.dart';
import 'package:vecinal_consola/features/ingreso/sign_in_page.dart';
import 'package:vecinal_consola/features/moderacion/presentation/moderation_page.dart';
import 'package:vecinal_consola/features/turnos/presentation/shifts_page.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(sessionProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: Routes.cases,
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.uri.path;
      if (session is! SignedIn) return location == Routes.signIn ? null : Routes.signIn;
      final home = homeFor(session.user);
      if (location == Routes.signIn || location == '/') return home;
      // Each section only for the roles that use it; the API checks the same roles again.
      final section = sectionOf(location);
      if (section != null && !session.user.canOpen(section)) return home;
      return null;
    },
    errorBuilder: (context, state) => const _NotFoundPage(),
    routes: [
      GoRoute(path: Routes.signIn, builder: (context, state) => const SignInPage()),
      ShellRoute(
        builder: (context, state, child) => ConsoleShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: Routes.cases,
            builder: (context, state) => const CasesQueuePage(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) =>
                    CaseDetailPage(caseId: state.pathParameters['id'] ?? ''),
              ),
            ],
          ),
          GoRoute(path: Routes.cells, builder: (context, state) => const CellsPage()),
          GoRoute(path: Routes.shifts, builder: (context, state) => const ShiftsPage()),
          GoRoute(path: Routes.moderation, builder: (context, state) => const ModerationPage()),
          GoRoute(
            path: Routes.curation,
            builder: (context, state) => const DirectoriesPage(),
            routes: [
              GoRoute(
                path: ':archivo',
                builder: (context, state) =>
                    DirectoryEditorPage(file: state.pathParameters['archivo'] ?? ''),
              ),
            ],
          ),
          GoRoute(
            path: Routes.urgentNotices,
            builder: (context, state) => const UrgentNoticesPage(),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});

class _NotFoundPage extends StatelessWidget {
  const _NotFoundPage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: CenteredMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InfoCard(icon: Icons.search_off, title: l10n.notFoundTitle, body: l10n.notFoundBody),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => context.go(Routes.cases), child: Text(l10n.goHome)),
          ],
        ),
      ),
    );
  }
}
