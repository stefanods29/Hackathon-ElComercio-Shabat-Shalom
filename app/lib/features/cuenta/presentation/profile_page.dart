import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/theme/accessible_theme.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/cuenta/data/privacy_providers.dart';
import 'package:vecinal/features/cuenta/data/profile_photo.dart';
import 'package:vecinal/features/cuenta/domain/privacy_repository.dart';
import 'package:vecinal/features/cuenta/presentation/account_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/reputacion/data/providers.dart';
import 'package:vecinal/l10n/app_localizations.dart';

/// Name and trust level the neighbor shows to the zone, with shortcuts to what they published.
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    final name = accountDisplayName(ref, t);
    final level = accountTrustLevel(ref);
    final zone = accountZoneName(ref);
    final reviews = ref.watch(myReviewsProvider).value?.length;
    return Scaffold(
      appBar: AppBar(title: Text(t.profileTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(child: MyProfileAvatar(name: name, radius: 46)),
                  const SizedBox(height: 14),
                  Text(name, textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  if (zone != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ExcludeSemantics(child: Icon(Icons.place_outlined, size: 18, color: muted)),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(zone, style: TextStyle(color: muted)),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(t.profileEditData),
                    onPressed: () => context.push(Routes.editProfile),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 12,
                children: [
                  Row(
                    children: [
                      const AccountIcon(icon: Icons.verified_outlined),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.profileTrustLevel(level),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(levelName(t, level), style: TextStyle(color: muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  TrustLevelMeter(level: level),
                  Text(levelAbilities(t, level)),
                  TextButton.icon(
                    icon: const Icon(Icons.trending_up),
                    label: Text(t.levelsTitle),
                    onPressed: () => context.push(Routes.levels),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          AccountSection(
            children: [
              AccountItem(
                icon: Icons.rate_review_outlined,
                title: t.profileMyReviews,
                subtitle: reviews == null ? null : t.profileReviewsCount(reviews),
                onTap: () => context.push('/cuenta/mis-resenas'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "Editar perfil": the name the zone sees, with the avatar updating as it is written.
class EditProfilePage extends ConsumerStatefulWidget {
  const EditProfilePage({super.key});
  @override
  ConsumerState<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends ConsumerState<EditProfilePage> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _loadedName;
  String? _nameError;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repository = ref.watch(privacyRepositoryProvider);
    final data = ref.watch(privacyDataProvider).value;
    final fallback = accountDisplayName(ref, t);
    final saved = data?.displayName ?? fallback;
    if (_loadedName != saved) {
      _loadedName = saved;
      _name.text = saved;
    }
    final level = accountTrustLevel(ref);
    final zone = accountZoneName(ref);
    return Scaffold(
      appBar: wrappingAppBar(context, t.profileEditData),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: spaced([
            if (!repository.available)
              EmergencyNotice(
                icon: Icons.info_outline,
                text: t.privacyUnavailable,
                tone: NoticeTone.info,
              ),
            if (data?.simulated == true)
              EmergencyNotice(
                icon: Icons.science_outlined,
                text: t.privacyDemo,
                tone: NoticeTone.info,
              ),
            ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, value, _) => ref.watch(profilePhotoEnabledProvider)
                  ? _ProfilePhotoEditor(name: value.text)
                  : Center(child: ProfileAvatar(name: value.text, radius: 46)),
            ),
            Form(
              key: _form,
              child: TextFormField(
                controller: _name,
                enabled: repository.available && !_busy,
                maxLength: 60,
                buildCounter:
                    (_, {required currentLength, required isFocused, required maxLength}) => null,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: t.visibleName,
                  floatingLabelBehavior: FloatingLabelBehavior.always,
                  prefixIcon: const Icon(Icons.person_outline),
                  helperText: t.editProfileNameHelp,
                  helperMaxLines: 3,
                  errorText: _nameError,
                  errorMaxLines: 3,
                ),
                validator: (name) =>
                    name == null || name.trim().length < 2 || name.trim().length > 60
                    ? t.invalidProviderName
                    : null,
              ),
            ),
            ValueListenableBuilder(
              valueListenable: _name,
              builder: (context, value, _) => FilledButton.icon(
                // Without a change the button rests flat: a shadow under a gray button looks broken.
                style: ButtonStyle(
                  elevation: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.disabled) ? 0 : 3,
                  ),
                ),
                icon: const Icon(Icons.check),
                label: Text(_busy ? t.loadingAction : t.correctName),
                onPressed: !repository.available || _busy || value.text.trim() == saved.trim()
                    ? null
                    : _save,
              ),
            ),
            const SizedBox(height: 4),
            AccountSection(
              children: [
                AccountItem(
                  icon: Icons.location_on_outlined,
                  title: zone ?? t.changeZone,
                  subtitle: zone == null ? null : t.changeZone,
                  onTap: () => context.push(Routes.changeZone),
                ),
                AccountItem(
                  icon: Icons.verified_outlined,
                  title: t.profileTrustLevel(level),
                  subtitle: t.levelsTitle,
                  onTap: () => context.push(Routes.levels),
                ),
              ],
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (ref.read(syncStatusProvider).value?.connected != true) {
      accountMessage(context, t.onlineRequired);
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
    });
    try {
      await ref.read(privacyRepositoryProvider).updateDisplayName(_name.text);
      if (!mounted) return;
      accountMessage(context, t.nameSaved);
      if (context.canPop()) context.pop();
    } on PrivacyFailure catch (error) {
      if (!mounted) return;
      if (error.field == 'displayName' || error.code == 'invalid_name') {
        setState(() => _nameError = t.invalidProviderName);
      } else {
        accountMessage(context, t.privacyUnavailable);
      }
    } catch (_) {
      if (mounted) accountMessage(context, t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The photo of the neighbor on this phone, with the actions to choose, change or remove it.
class _ProfilePhotoEditor extends ConsumerStatefulWidget {
  const _ProfilePhotoEditor({required this.name});
  final String name;
  @override
  ConsumerState<_ProfilePhotoEditor> createState() => _ProfilePhotoEditorState();
}

class _ProfilePhotoEditorState extends ConsumerState<_ProfilePhotoEditor> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final hasPhoto = ref.watch(profilePhotoProvider).value != null;
    final action = hasPhoto ? t.profilePhotoChange : t.profilePhotoAdd;
    return Column(
      spacing: 6,
      children: [
        Semantics(
          button: true,
          label: action,
          excludeSemantics: true,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _busy ? null : _pick,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                MyProfileAvatar(name: widget.name, radius: 52),
                if (_busy) const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AccessibleTheme.action(scheme),
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.surface, width: 3),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 18,
                      color: AccessibleTheme.onAction(scheme),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: Text(action),
              onPressed: _busy ? null : _pick,
            ),
            if (hasPhoto)
              TextButton.icon(
                icon: const Icon(Icons.no_photography_outlined),
                label: Text(t.profilePhotoRemove),
                onPressed: _busy ? null : _remove,
              ),
          ],
        ),
        Text(
          t.profilePhotoLocalNote,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Future<void> _pick() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final chosen = await ref.read(profilePhotoProvider.notifier).pick();
      if (chosen && mounted) accountMessage(context, t.profilePhotoSaved);
    } catch (_) {
      if (mounted) accountMessage(context, t.photosSelectionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove() async {
    final t = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(profilePhotoProvider.notifier).remove();
      if (mounted) accountMessage(context, t.profilePhotoRemoved);
    } catch (_) {
      if (mounted) accountMessage(context, t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// The neighbor's own avatar: their photo when they chose one on this phone, else the initial.
class MyProfileAvatar extends ConsumerWidget {
  const MyProfileAvatar({super.key, required this.name, this.radius = 28});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = ref.watch(profilePhotoEnabledProvider)
        ? ref.watch(profilePhotoProvider).value
        : null;
    if (photo == null) return ProfileAvatar(name: name, radius: radius);
    return ExcludeSemantics(
      child: CircleAvatar(radius: radius, backgroundImage: MemoryImage(photo)),
    );
  }
}

/// The neighbor's initial on a solid circle; no photo is needed to recognize the account.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.name, this.radius = 28});
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final initial = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: radius,
        backgroundColor: AccessibleTheme.action(scheme),
        foregroundColor: AccessibleTheme.onAction(scheme),
        child: Text(
          initial,
          style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
