import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/platform/pilot_platforms.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/cuenta/data/privacy_providers.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_repository.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/cuenta/domain/privacy_repository.dart';
import 'package:vecinal/features/cuenta/domain/zone.dart';
import 'package:vecinal/features/cuenta/presentation/account_ui.dart';
import 'package:vecinal/features/emergencias/presentation/emergency_ui.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class ConsentPage extends ConsumerStatefulWidget {
  const ConsentPage({super.key, this.registration = false});
  final bool registration;
  @override
  ConsumerState<ConsentPage> createState() => _ConsentPageState();
}

class _ConsentPageState extends ConsumerState<ConsentPage> {
  bool _service = false;
  bool _presence = false;
  bool _initialized = false;
  bool _busy = false;
  String? _error;
  Map<DataPurpose, String> _shownVersions = const {};
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repository = ref.watch(privacyRepositoryProvider);
    final data = ref.watch(privacyDataProvider).value;
    final versions = repository.consentTextVersions;
    if (_shownVersions.isNotEmpty &&
        DataPurpose.values.any((purpose) => _shownVersions[purpose] != versions[purpose])) {
      _service = false;
      _presence = false;
      _error = t.consentVersionChanged;
    }
    _shownVersions = Map.unmodifiable(versions);
    if (!_initialized && data != null) {
      _initialized = true;
      _service =
          data.consents[DataPurpose.service] == true &&
          data.consentVersions[DataPurpose.service] == versions[DataPurpose.service];
      _presence =
          data.consents[DataPurpose.residencePresence] == true &&
          data.consentVersions[DataPurpose.residencePresence] ==
              versions[DataPurpose.residencePresence];
    }
    return Scaffold(
      appBar: wrappingAppBar(context, t.consentTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            if (data?.simulated == true)
              EmergencyNotice(
                icon: Icons.science_outlined,
                text: t.privacyDemo,
                tone: NoticeTone.info,
              ),
            _ConsentCard(
              title: t.consentService,
              help: t.consentServiceHelp,
              version: _shownVersions[DataPurpose.service],
              value: _service,
              onChanged: _busy || !repository.available
                  ? null
                  : (value) => setState(() => _service = value == true),
            ),
            _ConsentCard(
              title: t.consentPresence,
              help: t.consentPresenceHelp,
              version: _shownVersions[DataPurpose.residencePresence],
              value: _presence,
              onChanged: _busy || !repository.available
                  ? null
                  : (value) => setState(() => _presence = value == true),
            ),
            if (!repository.available)
              EmergencyNotice(
                icon: Icons.info_outline,
                text: t.privacyUnavailable,
                tone: NoticeTone.info,
              ),
            if (_error != null)
              EmergencyNotice(
                icon: Icons.error_outline,
                text: _error!,
                tone: NoticeTone.danger,
                liveRegion: true,
              ),
            FilledButton(
              onPressed: _busy || !repository.available
                  ? null
                  : () async {
                      if (!_service) {
                        setState(() => _error = t.consentRequired);
                        return;
                      }
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await ref.read(privacyRepositoryProvider).saveConsents({
                          DataPurpose.service: _service,
                          DataPurpose.residencePresence: _presence,
                        }, textVersions: _shownVersions);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text(t.consentSaved)));
                        if (widget.registration) {
                          context.go(Routes.signIn);
                        } else if (context.canPop()) {
                          context.pop();
                        }
                      } on PrivacyFailure catch (error) {
                        if (mounted) {
                          setState(() {
                            _error = switch (error.code) {
                              'required_consent' => t.consentRequired,
                              'version_de_consentimiento_desactualizada' => t.consentVersionChanged,
                              _ => t.privacyUnavailable,
                            };
                            if (error.code == 'version_de_consentimiento_desactualizada') {
                              _service = false;
                              _presence = false;
                            }
                          });
                        }
                      } catch (_) {
                        if (mounted) setState(() => _error = t.actionFailed);
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(
                _busy
                    ? t.loadingAction
                    : widget.registration
                    ? t.continueAction
                    : t.saveChanges,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// One purpose of the data: the text stays as approved; only its frame is the app's.
class _ConsentCard extends StatelessWidget {
  const _ConsentCard({
    required this.title,
    required this.help,
    required this.version,
    required this.value,
    required this.onChanged,
  });
  final String title;
  final String help;
  final String? version;
  final bool value;
  final ValueChanged<bool?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: CheckboxListTile(
        contentPadding: const EdgeInsets.fromLTRB(20, 6, 14, 6),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 6,
          children: [
            Text(help),
            if (version != null)
              Text(
                t.consentTextVersion(version!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class MyDataPage extends ConsumerStatefulWidget {
  const MyDataPage({super.key});
  @override
  ConsumerState<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends ConsumerState<MyDataPage> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final repository = ref.watch(privacyRepositoryProvider);
    final data = ref.watch(privacyDataProvider);
    final lifecycle = ref.watch(accountOperationsRepositoryProvider);
    final value = data.value;
    return Scaffold(
      appBar: AppBar(title: Text(t.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            if (!repository.available)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EmergencyNotice(
                  icon: Icons.info_outline,
                  text: t.privacyUnavailable,
                  tone: NoticeTone.info,
                ),
              )
            else if (data.isLoading && value == null)
              const Center(child: CircularProgressIndicator())
            else if (data.hasError)
              Text(t.actionFailed)
            else if (value != null) ...[
              if (value.simulated)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EmergencyNotice(
                    icon: Icons.science_outlined,
                    text: t.privacyDemo,
                    tone: NoticeTone.info,
                  ),
                ),
              AccountSectionTitle(t.myDataStored),
              AccountSection(
                children: [
                  AccountItem(
                    icon: Icons.person_outline,
                    title: value.displayName,
                    subtitle: t.visibleName,
                    onTap: _busy ? null : () => context.push(Routes.editProfile),
                  ),
                  for (final entry in value.values.entries)
                    _DataRow(label: _fieldLabel(t, entry.key), value: entry.value.toString()),
                ],
              ),
            ],
            AccountSectionTitle(t.myDataRights),
            AccountSection(
              children: [
                if (repository.available && value != null)
                  Builder(
                    builder: (itemContext) => AccountItem(
                      icon: Icons.ios_share,
                      title: t.exportData,
                      subtitle: t.myDataExportSubtitle,
                      onTap: _busy ? null : () => _export(itemContext),
                    ),
                  ),
                AccountItem(
                  icon: Icons.fact_check_outlined,
                  title: t.consentTitle,
                  subtitle: t.myDataConsentSubtitle,
                  onTap: () => context.push(Routes.consent),
                ),
              ],
            ),
            AccountSectionTitle(t.deleteAccount),
            if (lifecycle?.supportsAccountLifecycle != true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: EmergencyNotice(
                  icon: Icons.info_outline,
                  text: t.privacyUnavailable,
                  tone: NoticeTone.info,
                ),
              ),
            AccountSection(
              children: [
                AccountItem(
                  icon: Icons.delete_outline,
                  title: t.deleteAccount,
                  subtitle: t.myDataDeleteSubtitle,
                  destructive: true,
                  onTap: _busy ? null : _delete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Friendly name of a stored field; an unknown one is shown with spaces and a capital.
  String _fieldLabel(AppLocalizations t, String key) {
    if (key == 'zona') return t.dataFieldZone;
    final words = key.replaceAll('_', ' ').trim();
    return words.isEmpty ? key : '${words[0].toUpperCase()}${words.substring(1)}';
  }

  Future<void> _export(BuildContext buttonContext) async {
    final t = AppLocalizations.of(context);
    if (ref.read(syncStatusProvider).value?.connected != true) {
      accountMessage(context, t.onlineRequired);
      return;
    }
    final origin = shareOrigin(buttonContext);
    setState(() => _busy = true);
    try {
      final data = await ref.read(privacyRepositoryProvider).exportData();
      final shared = await ref.read(appShareProvider).json(data, origin);
      if (mounted) accountMessage(context, shared ? t.exportReady : t.exportDismissed);
    } catch (_) {
      if (mounted) accountMessage(context, t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    if (ref.read(syncStatusProvider).value?.connected != true) {
      accountMessage(context, t.onlineRequired);
      return;
    }
    final practice = ref.read(practiceModeProvider).value;
    final repository = ref.read(accountOperationsRepositoryProvider);
    if (practice == null || repository?.supportsAccountLifecycle != true) {
      accountMessage(context, t.privacyUnavailable);
      return;
    }
    var checked = false;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (dialog, update) => AlertDialog(
          scrollable: true,
          title: Text(t.deleteAccount),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(t.deleteAccountBody),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.deleteConfirm),
                value: checked,
                onChanged: (value) => update(() => checked = value == true),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialog, false), child: Text(t.cancel)),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialog).colorScheme.error,
                foregroundColor: Theme.of(dialog).colorScheme.onError,
              ),
              onPressed: checked ? () => Navigator.pop(dialog, true) : null,
              child: Text(t.deleteAccount),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (ref.read(syncStatusProvider).value?.connected != true) {
      accountMessage(context, t.onlineRequired);
      return;
    }
    if (ref.read(practiceModeProvider).value != practice ||
        ref.read(accountOperationsRepositoryProvider) != repository) {
      accountMessage(context, t.privacyUnavailable);
      return;
    }
    setState(() => _busy = true);
    try {
      // A4 owns server acknowledgement and purge. Never sign out or wipe from the screen.
      await repository!.deleteAccount();
      if (practice) {
        ref.invalidate(practicePrivacyRepositoryProvider);
      }
      if (mounted) context.go(practice ? Routes.home : Routes.signIn);
    } on AccountCapabilityUnavailable {
      if (mounted) accountMessage(context, t.privacyUnavailable);
    } catch (_) {
      if (mounted) accountMessage(context, t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// A stored value that can only be read: its name over its value.
class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const AccountIcon(icon: Icons.location_on_outlined),
    title: SelectableText(value, style: const TextStyle(fontWeight: FontWeight.w600)),
    subtitle: Text(label),
  );
}

/// The four levels as a ladder: where the neighbor is and what the next step takes.
class LevelsPage extends ConsumerWidget {
  const LevelsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final level = accountTrustLevel(ref);
    return Scaffold(
      appBar: wrappingAppBar(context, t.levelsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: spaced([
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 12,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(t.currentLevel(level), style: theme.textTheme.headlineSmall),
                    ),
                    Text(
                      levelName(t, level),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    TrustLevelMeter(level: level),
                  ],
                ),
              ),
            ),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var step = 0; step <= maxTrustLevel; step++)
                      _LevelStep(step: step, current: level),
                  ],
                ),
              ),
            ),
            if (level == 0)
              OutlinedButton.icon(
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(t.levelsConsentAction, textAlign: TextAlign.center),
                onPressed: () => context.push(Routes.consent),
              ),
          ]),
        ),
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({required this.step, required this.current});
  final int step;
  final int current;

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reached = step <= current;
    final here = step == current;
    final isLast = step == maxTrustLevel;
    final next = here ? levelNextStep(t, step) : null;
    final muted = TextStyle(color: scheme.onSurfaceVariant);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: reached ? scheme.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: reached ? scheme.primary : scheme.outline,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$step',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: reached ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 3,
                      color: step < current ? scheme.primary : scheme.outlineVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 20, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 4,
                children: [
                  Text(
                    '${t.levelShort(step)} · ${levelName(t, step)}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: reached ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                  if (here)
                    EmergencyPill(
                      icon: Icons.place,
                      text: t.levelsYouAreHere,
                      background: scheme.primaryContainer,
                      foreground: scheme.onPrimaryContainer,
                    ),
                  Text(levelAbilities(t, step), style: reached ? null : muted),
                  if (next != null) ...[
                    const SizedBox(height: 4),
                    Text(t.levelsNextTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text(next),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChangeZonePage extends ConsumerStatefulWidget {
  const ChangeZonePage({super.key});
  @override
  ConsumerState<ChangeZonePage> createState() => _ChangeZonePageState();
}

class _ChangeZonePageState extends ConsumerState<ChangeZonePage> {
  bool _busy = false;
  String? _error;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final sync = ref.watch(syncStatusProvider);
    final repository = ref.watch(accountOperationsRepositoryProvider);
    final ready = sync.hasValue && sync.value!.connected && sync.value!.pendingUploads == 0;
    final auth = ref.watch(authStateProvider).value;
    final currentId = ref.watch(practiceModeProvider).value == false && auth is SignedIn
        ? auth.user.zoneId
        : null;
    return Scaffold(
      appBar: wrappingAppBar(context, t.changeZone),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: spaced([
            Text(
              t.changeZoneBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (!sync.hasValue || sync.value!.pendingUploads > 0)
              EmergencyNotice(icon: Icons.upload_outlined, text: t.pendingZoneWarning),
            if (sync.value?.connected != true)
              EmergencyNotice(icon: Icons.cloud_off_outlined, text: t.onlineRequired),
            if (repository?.supportsAccountLifecycle != true)
              EmergencyNotice(
                icon: Icons.info_outline,
                text: t.privacyUnavailable,
                tone: NoticeTone.info,
              ),
            if (_error != null)
              EmergencyNotice(
                icon: Icons.error_outline,
                text: _error!,
                tone: NoticeTone.danger,
                liveRegion: true,
              ),
            if (repository?.supportsAccountLifecycle == true && ready)
              FutureBuilder(
                future: ref.watch(accountZonesProvider.future),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return snapshot.hasError
                        ? Text(t.actionFailed)
                        : const Center(child: CircularProgressIndicator());
                  }
                  final zones = snapshot.data!;
                  final current = zones.where((zone) => zone.id == currentId).firstOrNull;
                  final others = zones.where((zone) => zone.id != currentId).toList();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (current != null) ...[
                        AccountSectionTitle(t.zoneCurrent),
                        AccountSection(
                          children: [
                            ListTile(
                              leading: const AccountIcon(icon: Icons.where_to_vote_outlined),
                              title: Text(
                                current.name,
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(current.district),
                            ),
                          ],
                        ),
                      ],
                      AccountSectionTitle(t.zoneChooseNew),
                      AccountSection(
                        children: [
                          for (final zone in others)
                            AccountItem(
                              icon: Icons.location_on_outlined,
                              title: zone.name,
                              subtitle: zone.district,
                              onTap: _busy ? null : () => _change(zone),
                            ),
                        ],
                      ),
                    ],
                  );
                },
              ),
          ]),
        ),
      ),
    );
  }

  Future<void> _change(Zone zone) async {
    final t = AppLocalizations.of(context);
    final confirmed = await confirmAccountAction(
      context,
      title: t.zoneConfirmTitle(zone.name),
      body: t.zoneConfirmBody,
      action: t.changeZone,
    );
    if (!confirmed || !mounted) return;
    final sync = ref.read(syncStatusProvider);
    if (!sync.hasValue || sync.value!.pendingUploads > 0) {
      setState(() => _error = t.pendingZoneWarning);
      return;
    }
    if (!sync.value!.connected) {
      setState(() => _error = t.onlineRequired);
      return;
    }
    final repository = ref.read(accountOperationsRepositoryProvider);
    if (repository?.supportsAccountLifecycle != true) {
      setState(() => _error = t.privacyUnavailable);
      return;
    }
    final practice = ref.read(practiceModeProvider).value != false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await repository!.changeZone(zone.id);
      if (!mounted) return;
      accountMessage(context, practice ? t.zonePracticeDone(zone.name) : t.zoneChanged(zone.name));
      context.go(Routes.home);
    } on ZoneChangeTooSoon catch (error) {
      if (mounted) {
        final from = error.availableFrom?.toLocal();
        setState(
          () => _error = from == null
              ? t.zoneTooSoonNoDate
              : t.zoneTooSoon(DateFormat.yMd(t.localeName).format(from)),
        );
      }
    } on PendingUploadsBlockZoneChange {
      if (mounted) setState(() => _error = t.pendingZoneWarning);
    } catch (_) {
      if (mounted) setState(() => _error = t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

final accountZonesProvider = FutureProvider((ref) async {
  final repository = ref.watch(accountOperationsRepositoryProvider);
  if (repository?.supportsAccountLifecycle != true) throw const AccountCapabilityUnavailable();
  return repository!.listZones();
});
