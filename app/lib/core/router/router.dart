import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/under_construction_screen.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/presentation/account_page.dart';
import 'package:vecinal/features/cuenta/presentation/choose_zone_page.dart';
import 'package:vecinal/features/cuenta/presentation/code_page.dart';
import 'package:vecinal/features/cuenta/presentation/phone_page.dart';
import 'package:vecinal/features/onboarding/tutorial_screen.dart';
import 'package:vecinal/features/publicar/presentation/choose_type_page.dart';
import 'package:vecinal/features/publicar/presentation/publish_form_page.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/presentation/actions_to_review_page.dart';
import 'package:vecinal/features/solidaridad/presentation/wall_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authStateProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: Routes.home,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider).value;
      final current = state.matchedLocation;
      final isSignIn = current == Routes.signIn;
      final isSignInCode = current == Routes.signInCode;
      final isChooseZone = current == Routes.chooseZone;

      if (authState == null || authState is SignedOut) {
        if (!isSignIn && !isSignInCode) {
          return Routes.signIn;
        }
      } else if (authState is NeedsZone) {
        if (!isChooseZone) {
          return Routes.chooseZone;
        }
      } else if (authState is SignedIn) {
        if (isSignIn || isSignInCode || isChooseZone) {
          return Routes.home;
        }
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.home, builder: (context, state) => const WallPage()),
      GoRoute(path: Routes.signIn, builder: (context, state) => const PhonePage()),
      GoRoute(
        path: Routes.signInCode,
        builder: (context, state) {
          final arguments = state.extra as CodeArguments?;
          return CodePage(
            phone: arguments?.phone ?? '',
            retryAfterSeconds: arguments?.retryAfterSeconds ?? 30,
          );
        },
      ),
      GoRoute(path: Routes.chooseZone, builder: (context, state) => const ChooseZonePage()),
      GoRoute(path: Routes.account, builder: (context, state) => const AccountPage()),
      GoRoute(path: Routes.publish, builder: (context, state) => const ChooseTypePage()),
      GoRoute(
        path: Routes.publishForm,
        builder: (context, state) {
          final tipo = state.pathParameters['tipo']!;
          final postType = PostType.fromApi(tipo);
          return PublishFormPage(type: postType);
        },
      ),
      GoRoute(path: Routes.toReview, builder: (context, state) => const ActionsToReviewPage()),
      GoRoute(
        path: Routes.map,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Mapa sin conexión', lot: 'Lote C'),
      ),
      GoRoute(
        path: Routes.emergency,
        builder: (context, state) =>
            const UnderConstructionScreen(title: 'Modo emergencia', lot: 'equipo en la Fase 1'),
      ),
      GoRoute(path: Routes.tutorial, builder: (context, state) => const TutorialScreen()),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
