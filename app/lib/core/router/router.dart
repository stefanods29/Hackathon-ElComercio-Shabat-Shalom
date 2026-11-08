import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/features/avisos/presentation/push_settings_page.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/presentation/account_page.dart';
import 'package:vecinal/features/cuenta/presentation/choose_zone_page.dart';
import 'package:vecinal/features/cuenta/presentation/code_page.dart';
import 'package:vecinal/features/cuenta/presentation/phone_page.dart';
import 'package:vecinal/features/cuenta/presentation/privacy_pages.dart';
import 'package:vecinal/features/directorio/presentation/directory_page.dart';
import 'package:vecinal/features/directorio/presentation/service_detail_page.dart';
import 'package:vecinal/features/directorio/presentation/service_form_page.dart';
import 'package:vecinal/features/emergencias/domain/emergency.dart';
import 'package:vecinal/features/emergencias/emergency_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_contacts_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_dashboard_page.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_resource_pages.dart';
import 'package:vecinal/features/emergencias/presentation/help_request_pages.dart';
import 'package:vecinal/features/mapa/presentation/map_page.dart';
import 'package:vecinal/features/mapa/presentation/map_view.dart';
import 'package:vecinal/features/onboarding/tutorial_screen.dart';
import 'package:vecinal/features/publicar/presentation/choose_type_page.dart';
import 'package:vecinal/features/publicar/presentation/publish_form_page.dart';
import 'package:vecinal/features/reputacion/presentation/review_page.dart';
import 'package:vecinal/features/reputacion/presentation/reviews_section.dart';
import 'package:vecinal/features/solidaridad/domain/post.dart';
import 'package:vecinal/features/solidaridad/presentation/actions_to_review_page.dart';
import 'package:vecinal/features/solidaridad/presentation/post_detail_page.dart';
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
      // Institutional phones and verified public points never require a session.
      if (current == Routes.emergency ||
          current == Routes.emergencyDashboard ||
          current == Routes.emergencyMap ||
          current == Routes.consent)
        return null;
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
      GoRoute(path: '/cuenta/mis-resenas', builder: (context, state) => const MyReviewsPage()),
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
      GoRoute(
        path: Routes.consent,
        builder: (context, state) =>
            ConsentPage(registration: state.uri.queryParameters['registro'] == '1'),
      ),
      GoRoute(path: Routes.myData, builder: (context, state) => const MyDataPage()),
      GoRoute(path: Routes.levels, builder: (context, state) => const LevelsPage()),
      GoRoute(path: Routes.changeZone, builder: (context, state) => const ChangeZonePage()),
      GoRoute(path: Routes.publish, builder: (context, state) => const ChooseTypePage()),
      GoRoute(path: Routes.publishService, builder: (context, state) => const ServiceFormPage()),
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
        builder: (context, state) => MapPage(focus: state.extra as MapFocus?),
      ),
      GoRoute(
        path: Routes.directory,
        builder: (context, state) =>
            DirectoryPage(emergencyOnly: state.uri.queryParameters['emergencia'] == '1'),
      ),
      GoRoute(
        path: Routes.serviceReview,
        builder: (context, state) => ReviewPage(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.serviceDetail,
        builder: (context, state) => ServiceDetailPage(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.editService,
        builder: (context, state) => ServiceFormPage(serviceId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: Routes.providerProfile,
        builder: (context, state) => ProviderProfilePage(providerId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.pushSettings, builder: (context, state) => const PushSettingsPage()),
      GoRoute(
        path: Routes.postDetail,
        builder: (context, state) => PostDetailPage(postId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.emergency, builder: (context, state) => const EmergencyPage()),
      GoRoute(
        path: Routes.emergencyDashboard,
        builder: (context, state) => const EmergencyDashboardPage(),
      ),
      GoRoute(path: Routes.emergencyNeeds, builder: (context, state) => const EmergencyNeedsPage()),
      GoRoute(
        path: Routes.emergencyRequestForm,
        builder: (context, state) {
          final need = EmergencyNeed.values
              .where((value) => value.name == state.pathParameters['need'])
              .firstOrNull;
          return HelpRequestFormPage(key: ValueKey(need), need: need ?? EmergencyNeed.other);
        },
      ),
      GoRoute(
        path: Routes.emergencyRequest,
        builder: (context, state) => OwnHelpRequestPage(requestId: state.pathParameters['id']!),
      ),
      GoRoute(path: Routes.emergencyOffer, builder: (context, state) => const EmergencyOfferPage()),
      GoRoute(
        path: Routes.emergencyResources,
        builder: (context, state) => const EmergencyResourcesPage(),
      ),
      GoRoute(
        path: Routes.emergencyContacts,
        builder: (context, state) => const EmergencyContactsPage(),
      ),
      GoRoute(
        path: Routes.emergencyMap,
        builder: (context, state) => MapPage(focus: state.extra as MapFocus?),
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
