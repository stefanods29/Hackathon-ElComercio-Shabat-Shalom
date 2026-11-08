import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import 'package:vecinal/features/onboarding/demo_profiles.dart';
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
            if (data?.simulated == true) Text(t.privacyDemo),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.consentService),
              subtitle: Text(t.consentServiceHelp),
              value: _service,
              onChanged: _busy || !repository.available
                  ? null
                  : (value) => setState(() => _service = value == true),
            ),
            if (_shownVersions[DataPurpose.service] case final version?)
              Text(t.consentTextVersion(version)),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.consentPresence),
              subtitle: Text(t.consentPresenceHelp),
              value: _presence,
              onChanged: _busy || !repository.available
                  ? null
                  : (value) => setState(() => _presence = value == true),
            ),
            if (_shownVersions[DataPurpose.residencePresence] case final version?)
              Text(t.consentTextVersion(version)),
            if (!repository.available) Text(t.privacyUnavailable),
            if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
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

class MyDataPage extends ConsumerStatefulWidget {
  const MyDataPage({super.key});
  @override
  ConsumerState<MyDataPage> createState() => _MyDataPageState();
}

class _MyDataPageState extends ConsumerState<MyDataPage> {
  final _name = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _loadedName;
  String? _nameError;
  String? _message;
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
    final data = ref.watch(privacyDataProvider);
    final lifecycle = ref.watch(accountOperationsRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: Text(t.privacyTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            if (!repository.available)
              Text(t.privacyUnavailable)
            else
              data.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => Text(t.actionFailed),
                data: (value) {
                  if (_loadedName != value.displayName) {
                    _loadedName = value.displayName;
                    _name.text = value.displayName;
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 14,
                    children: [
                      if (value.simulated) Text(t.privacyDemo),
                      for (final entry in value.values.entries)
                        SelectableText(t.dataField(entry.key, entry.value.toString())),
                      Form(
                        key: _form,
                        child: TextFormField(
                          controller: _name,
                          decoration: InputDecoration(
                            labelText: t.visibleName,
                            errorText: _nameError,
                          ),
                          validator: (name) =>
                              name == null || name.trim().length < 2 || name.trim().length > 60
                              ? t.invalidProviderName
                              : null,
                        ),
                      ),
                      FilledButton(
                        onPressed: _busy ? null : _updateName,
                        child: Text(t.correctName),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.ios_share),
                        label: Text(t.exportData),
                        onPressed: _busy ? null : () => _export(context),
                      ),
                    ],
                  );
                },
              ),
            OutlinedButton(
              onPressed: () => context.push(Routes.consent),
              child: Text(t.consentTitle),
            ),
            const Divider(),
            Text(t.deleteAccountBody),
            if (lifecycle?.supportsAccountLifecycle != true) Text(t.privacyUnavailable),
            OutlinedButton.icon(
              icon: const Icon(Icons.delete_outline),
              label: Text(t.deleteAccount),
              onPressed: _busy ? null : _delete,
            ),
            if (_message != null) Semantics(liveRegion: true, child: Text(_message!)),
          ]),
        ),
      ),
    );
  }

  Future<void> _updateName() async {
    final t = AppLocalizations.of(context);
    if (!_form.currentState!.validate()) return;
    if (ref.read(syncStatusProvider).value?.connected != true) {
      setState(() => _message = t.onlineRequired);
      return;
    }
    setState(() {
      _busy = true;
      _nameError = null;
      _message = null;
    });
    try {
      await ref.read(privacyRepositoryProvider).updateDisplayName(_name.text);
      if (mounted) setState(() => _message = t.nameSaved);
    } on PrivacyFailure catch (error) {
      if (mounted) {
        setState(() {
          if (error.field == 'displayName' || error.code == 'invalid_name') {
            _nameError = t.invalidProviderName;
          } else {
            _message = t.privacyUnavailable;
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _export(BuildContext buttonContext) async {
    final t = AppLocalizations.of(context);
    if (ref.read(syncStatusProvider).value?.connected != true) {
      setState(() => _message = t.onlineRequired);
      return;
    }
    final origin = shareOrigin(buttonContext);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final data = await ref.read(privacyRepositoryProvider).exportData();
      final shared = await ref.read(appShareProvider).json(data, origin);
      if (mounted) setState(() => _message = shared ? t.exportReady : t.exportDismissed);
    } catch (_) {
      if (mounted) setState(() => _message = t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final t = AppLocalizations.of(context);
    if (ref.read(syncStatusProvider).value?.connected != true) {
      setState(() => _message = t.onlineRequired);
      return;
    }
    final practice = ref.read(practiceModeProvider).value;
    final repository = ref.read(accountOperationsRepositoryProvider);
    if (practice == null || repository?.supportsAccountLifecycle != true) {
      setState(() => _message = t.privacyUnavailable);
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
              onPressed: checked ? () => Navigator.pop(dialog, true) : null,
              child: Text(t.deleteAccount),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    if (ref.read(syncStatusProvider).value?.connected != true) {
      setState(() => _message = t.onlineRequired);
      return;
    }
    if (ref.read(practiceModeProvider).value != practice ||
        ref.read(accountOperationsRepositoryProvider) != repository) {
      setState(() => _message = t.privacyUnavailable);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      // A4 owns server acknowledgement and purge. Never sign out or wipe from the screen.
      await repository!.deleteAccount();
      if (practice) {
        ref.invalidate(practicePrivacyRepositoryProvider);
      }
      if (mounted) context.go(practice ? Routes.home : Routes.signIn);
    } on AccountCapabilityUnavailable {
      if (mounted) setState(() => _message = t.privacyUnavailable);
    } catch (_) {
      if (mounted) setState(() => _message = t.actionFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class LevelsPage extends ConsumerWidget {
  const LevelsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = AppLocalizations.of(context);
    final auth = ref.watch(authStateProvider).value;
    final level = ref.watch(practiceModeProvider).value == true
        ? ref.watch(effectiveSessionProvider).trustLevel
        : auth is SignedIn
        ? auth.user.trustLevel
        : 0;
    return Scaffold(
      appBar: wrappingAppBar(context, t.levelsTitle),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            Text(t.currentLevel(level), style: Theme.of(context).textTheme.headlineSmall),
            for (final text in [t.levelZero, t.levelOne, t.levelTwo, t.levelThree])
              Card(
                child: Padding(padding: const EdgeInsets.all(16), child: Text(text)),
              ),
            OutlinedButton(
              onPressed: () => context.push(Routes.consent),
              child: Text(t.consentTitle),
            ),
          ]),
        ),
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
  String? _message;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final sync = ref.watch(syncStatusProvider);
    final repository = ref.watch(accountOperationsRepositoryProvider);
    final ready = sync.hasValue && sync.value!.connected && sync.value!.pendingUploads == 0;
    return Scaffold(
      appBar: wrappingAppBar(context, t.changeZone),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            Text(t.changeZoneBody),
            if (!sync.hasValue || sync.value!.pendingUploads > 0) Text(t.pendingZoneWarning),
            if (sync.value?.connected != true) Text(t.onlineRequired),
            if (repository?.supportsAccountLifecycle != true) Text(t.privacyUnavailable),
            if (repository?.supportsAccountLifecycle == true && ready)
              FutureBuilder(
                future: ref.watch(accountZonesProvider.future),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return Text(snapshot.hasError ? t.actionFailed : t.chooseZoneSubtitle);
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 12,
                    children: [
                      for (final zone in snapshot.data!)
                        OutlinedButton(
                          onPressed: _busy ? null : () => _change(zone.id),
                          child: Text('${zone.name} · ${zone.district}'),
                        ),
                    ],
                  );
                },
              ),
            if (_message != null) Text(_message!),
          ]),
        ),
      ),
    );
  }

  Future<void> _change(String zoneId) async {
    final t = AppLocalizations.of(context);
    final sync = ref.read(syncStatusProvider);
    if (!sync.hasValue || sync.value!.pendingUploads > 0) {
      setState(() => _message = t.pendingZoneWarning);
      return;
    }
    if (!sync.value!.connected) {
      setState(() => _message = t.onlineRequired);
      return;
    }
    final repository = ref.read(accountOperationsRepositoryProvider);
    if (repository?.supportsAccountLifecycle != true) {
      setState(() => _message = t.privacyUnavailable);
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await repository!.changeZone(zoneId);
      if (mounted) context.go(Routes.home);
    } catch (_) {
      if (mounted) setState(() => _message = t.actionFailed);
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
