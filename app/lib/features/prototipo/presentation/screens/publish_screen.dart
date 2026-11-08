import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_publish_form.dart';

class PublishScreen extends StatelessWidget {
  const PublishScreen({super.key, this.initialType});

  final String? initialType;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ProtoPublishForm(
      initialType: initialType,
      onPublished: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
      onCancel: () => ProtoNavigation.back(context),
    ),
  );
}
