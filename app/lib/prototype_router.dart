import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/screens/account_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/actions_to_review_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/code_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/emergency_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/login_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/map_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/post_detail_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/push_settings_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/publish_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/tutorial_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/welcome_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/zone_screen.dart';

export 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart'
    show ProtoRoutes;

final prototypeRouter = createPrototypeRouter();

GoRouter createPrototypeRouter({String initialLocation = ProtoRoutes.welcome}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(path: ProtoRoutes.welcome, builder: (context, _) => const WelcomeScreen()),
    GoRoute(
      path: ProtoRoutes.mapa,
      builder: (context, state) =>
          MapScreen(tab: ProtoHomeTab.fromQuery(state.uri.queryParameters['vista'])),
    ),
    GoRoute(path: ProtoRoutes.login, builder: (context, _) => const LoginScreen()),
    GoRoute(path: ProtoRoutes.code, builder: (context, _) => const CodeScreen()),
    GoRoute(path: ProtoRoutes.zone, builder: (context, _) => const ZoneScreen()),
    GoRoute(path: ProtoRoutes.publish, builder: (context, _) => const PublishScreen()),
    GoRoute(
      path: ProtoRoutes.publishForm,
      builder: (context, state) => PublishScreen(initialType: state.pathParameters['tipo']),
    ),
    GoRoute(path: ProtoRoutes.toReview, builder: (context, _) => const ActionsToReviewScreen()),
    GoRoute(path: ProtoRoutes.emergency, builder: (context, _) => const EmergencyScreen()),
    GoRoute(path: ProtoRoutes.tutorial, builder: (context, _) => const TutorialScreen()),
    GoRoute(path: ProtoRoutes.account, builder: (context, _) => const AccountScreen()),
    GoRoute(path: ProtoRoutes.pushSettings, builder: (context, _) => const PushSettingsScreen()),
    GoRoute(
      path: ProtoRoutes.postDetail,
      builder: (context, state) => PostDetailScreen(postId: state.pathParameters['id'] ?? 'post-1'),
    ),
  ],
);
