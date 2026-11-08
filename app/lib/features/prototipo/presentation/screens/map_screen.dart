import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/features/prototipo/data/mock_data.dart';
import 'package:vecinal/features/prototipo/data/models.dart';
import 'package:vecinal/features/prototipo/presentation/navigation/proto_navigation.dart';
import 'package:vecinal/features/prototipo/presentation/screens/account_screen.dart';
import 'package:vecinal/features/prototipo/presentation/theme/app_theme.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_button.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_post_card.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_publish_form.dart';
import 'package:vecinal/features/prototipo/presentation/widgets/proto_status_badge.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// The selected tab is part of the route, so every entry point agrees on it.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.tab = ProtoHomeTab.map});

  final ProtoHomeTab tab;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  void _selectTab(ProtoHomeTab tab) {
    _scaffoldKey.currentState?.closeDrawer();
    FocusScope.of(context).unfocus();
    context.go(ProtoRoutes.home(tab));
  }

  void _open(String route) {
    _scaffoldKey.currentState?.closeDrawer();
    ProtoNavigation.open(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final labels = [l10n.protoMapTab, l10n.protoWallTab, l10n.publishAction, l10n.protoAccountTab];
    const icons = [
      Icons.map_outlined,
      Icons.feed_outlined,
      Icons.add_circle_outline,
      Icons.person_outline,
    ];
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        leading: IconButton(
          tooltip: l10n.protoOpenMenu,
          icon: const Icon(Icons.menu),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        title: const Text('Winki', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: l10n.actionsToReview,
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => _open(ProtoRoutes.toReview),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                color: kPrimaryColor,
                child: Column(
                  children: [
                    const Icon(Icons.sentiment_very_satisfied, size: 48, color: Colors.white),
                    const SizedBox(height: 12),
                    const Text(
                      'Winki',
                      style: TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(l10n.protoMainMenu, style: const TextStyle(color: Colors.white)),
                  ],
                ),
              ),
              for (final tab in ProtoHomeTab.values)
                ListTile(
                  leading: Icon(icons[tab.index]),
                  title: Text(labels[tab.index]),
                  selected: widget.tab == tab,
                  selectedColor: kPrimaryColor,
                  onTap: () => _selectTab(tab),
                ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: Text(l10n.viewTutorial),
                onTap: () => _open(ProtoRoutes.tutorial),
              ),
              ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text(l10n.protoEmergency),
                onTap: () => _open(ProtoRoutes.emergency),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_outlined),
                title: Text(l10n.pushTitle),
                onTap: () => _open(ProtoRoutes.pushSettings),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: kErrorColor),
                title: Text(l10n.signOut, style: const TextStyle(color: kErrorColor)),
                onTap: () {
                  _scaffoldKey.currentState?.closeDrawer();
                  context.go(ProtoRoutes.login);
                },
              ),
              ListTile(
                leading: const Icon(Icons.phone_disabled, color: kErrorColor),
                title: Text(l10n.lostPhone, style: const TextStyle(color: kErrorColor)),
                onTap: () => _scaffoldKey.currentState?.closeDrawer(),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(l10n.protoTagline, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
      // Keep a draft and scroll positions while switching between home tabs.
      body: IndexedStack(
        index: widget.tab.index,
        children: [
          const _MapTab(),
          const _WallTab(),
          ProtoPublishForm(
            onPublished: () => _selectTab(ProtoHomeTab.wall),
            onCancel: () => _selectTab(ProtoHomeTab.map),
          ),
          const AccountContent(),
        ],
      ),
      bottomNavigationBar: Material(
        color: kSurfaceColor,
        elevation: 0,
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final tab in ProtoHomeTab.values)
                Expanded(
                  child: Semantics(
                    selected: widget.tab == tab,
                    button: true,
                    child: InkWell(
                      key: ValueKey<String>('home-tab-${tab.name}'),
                      onTap: () => _selectTab(tab),
                      borderRadius: BorderRadius.circular(kRadiusLarge),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: kMotionPress,
                              constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: widget.tab == tab
                                    ? kPrimaryColor.withValues(alpha: 0.10)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(kRadiusPill),
                              ),
                              child: Icon(
                                icons[tab.index],
                                color: widget.tab == tab ? kPrimaryColor : kTextSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              labels[tab.index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: widget.tab == tab ? FontWeight.bold : FontWeight.w500,
                                color: widget.tab == tab ? kPrimaryColor : kTextSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapTab extends StatelessWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        key: const PageStorageKey('prototype-map'),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.protoMapHeading, style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 8),
            Text(l10n.protoNearbyPosts, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 20),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map_outlined, size: 26, color: kSecondaryColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.protoMapPlaceholder,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
                        final columns = (constraints.maxWidth / (240 * scale)).floor().clamp(1, 3);
                        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final post in mockPosts)
                              SizedBox(
                                width: width,
                                child: _MapMarker(post: post),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            ProtoButton(
              text: l10n.viewTutorial,
              icon: Icons.play_circle_outline,
              onPressed: () => ProtoNavigation.open(context, ProtoRoutes.tutorial),
              secondary: true,
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Mock markers flow with the available width instead of sharing coordinates.
class _MapMarker extends StatelessWidget {
  const _MapMarker({required this.post});
  final PostProto post;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    child: Material(
      color: kSurfaceColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => ProtoNavigation.open(context, '/publicaciones/${post.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, color: kPrimaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      post.typeLabel,
                      style: const TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: kTextColor,
                ),
              ),
              const SizedBox(height: 12),
              ProtoStatusBadge(post: post),
            ],
          ),
        ),
      ),
    ),
  );
}

class _WallTab extends StatelessWidget {
  const _WallTab();

  @override
  Widget build(BuildContext context) => SafeArea(
    child: mockPosts.isEmpty
        ? Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Text(AppLocalizations.of(context).wallEmpty),
            ),
          )
        : ListView.builder(
            key: const PageStorageKey('prototype-wall'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: mockPosts.length,
            itemBuilder: (context, index) => ProtoPostCard(
              post: mockPosts[index],
              onTap: () => ProtoNavigation.open(context, '/publicaciones/${mockPosts[index].id}'),
            ),
          ),
  );
}
