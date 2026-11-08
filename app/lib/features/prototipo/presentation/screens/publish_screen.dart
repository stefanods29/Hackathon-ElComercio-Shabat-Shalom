import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_publish_form.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PublishScreen extends StatelessWidget {
  const PublishScreen({super.key, this.initialType});

  final String? initialType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.publishAction),
        leading: IconButton(
          key: const ValueKey<String>('publish-back'),
          tooltip: l10n.protoBack,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => ProtoNavigation.back(context),
        ),
      ),
      body: ProtoPublishForm(
        initialType: initialType,
        onPublished: () => context.go(ProtoRoutes.home(ProtoHomeTab.wall)),
        onCancel: () => ProtoNavigation.back(context),
      ),
    );
  }
}
