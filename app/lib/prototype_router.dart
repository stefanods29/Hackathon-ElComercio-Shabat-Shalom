import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/screens/account_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/actions_to_review_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/code_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/emergency_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/login_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/map_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/post_detail_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/publish_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/push_settings_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/tutorial_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/wall_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/welcome_screen.dart';
import 'package:vecinal/features/prototipo/presentation/screens/zone_screen.dart';

abstract final class ProtoRoutes {
  static const welcome = '/';
  static const login = '/ingresar';
  static const code = '/ingresar/codigo';
  static const zone = '/elegir-zona';
  static const wall = '/';
  static const publish = '/publicar';
  static const publishForm = '/publicar/:tipo';
  static const toReview = '/por-revisar';
  static const emergency = '/emergencia';
  static const map = '/mapa';
  static const tutorial = '/tutorial';
  static const account = '/cuenta';
  static const pushSettings = '/avisos';
  static const postDetail = '/publicaciones/:id';
}

final prototypeRouter = GoRouter(
  initialLocation: ProtoRoutes.welcome,
  routes: [
    GoRoute(path: ProtoRoutes.welcome, builder: (context, _) => const WelcomeScreen()),
    GoRoute(path: ProtoRoutes.login, builder: (context, _) => const LoginScreen()),
    GoRoute(path: ProtoRoutes.code, builder: (context, _) => const CodeScreen()),
    GoRoute(path: ProtoRoutes.zone, builder: (context, _) => const ZoneScreen()),
    GoRoute(path: ProtoRoutes.wall, builder: (context, _) => const WallScreen()),
    GoRoute(path: ProtoRoutes.publish, builder: (context, _) => const PublishScreen()),
    GoRoute(path: ProtoRoutes.publishForm, builder: (context, _) => const PublishScreen()),
    GoRoute(path: ProtoRoutes.toReview, builder: (context, _) => const ActionsToReviewScreen()),
    GoRoute(path: ProtoRoutes.emergency, builder: (context, _) => const EmergencyScreen()),
    GoRoute(path: ProtoRoutes.map, builder: (context, _) => const MapScreen()),
    GoRoute(path: ProtoRoutes.tutorial, builder: (context, _) => const TutorialScreen()),
    GoRoute(path: ProtoRoutes.account, builder: (context, _) => const AccountScreen()),
    GoRoute(path: ProtoRoutes.pushSettings, builder: (context, _) => const PushSettingsScreen()),
    GoRoute(
      path: ProtoRoutes.postDetail,
      builder: (context, state) => PostDetailScreen(postId: state.pathParameters['id'] ?? 'post-1'),
    ),
  ],
);
