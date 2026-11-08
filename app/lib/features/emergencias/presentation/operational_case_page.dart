import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/security/operational_gate.dart';
import 'package:vecinal/core/security/operational_lock.dart';
import 'package:vecinal/core/security/sensitive_screen_protection.dart';
import 'package:vecinal/core/ui/spaced.dart';
import 'package:vecinal/features/cuenta/data/providers.dart';
import 'package:vecinal/features/cuenta/domain/auth_state.dart';
import 'package:vecinal/features/emergencias/assigned_case_cache.dart';
import 'package:vecinal/features/emergencias/assigned_case_provider.dart';
import 'package:vecinal/features/emergencias/domain/own_help_request_state.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

final operationalLockProvider = Provider<OperationalLock>((ref) => DeviceOperationalLock());
final sensitiveScreenProtectionProvider = Provider<SensitiveScreenProtection>(
  (ref) => SensitiveScreenProtection.shared,
);

class OperationalCasePage extends ConsumerWidget {
  const OperationalCasePage({super.key, required this.caseId});

  final String caseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final auth = ref.watch(authStateProvider).asData?.value;
    final practice = ref.watch(practiceModeProvider).asData?.value;
    final cache = ref.watch(assignedCaseCacheProvider);
    final current = ModalRoute.isCurrentOf(context) ?? true;
    final clock = ref.watch(clockProvider);
    final id = caseId.toLowerCase();
    final allowed =
        auth is SignedIn &&
        cache != null &&
        cache.accountId == auth.user.neighborId &&
        practice == false &&
        Uuid.isValidUUID(fromString: id);
    return Scaffold(
      appBar: AppBar(title: Text(texts.operationalTitle)),
      body: SafeArea(
        child: !current
            ? const SizedBox.shrink()
            : !allowed
            ? Center(child: Text(texts.operationalCaseUnavailable))
            : OperationalGate(
                key: ValueKey((cache, id)),
                lock: ref.watch(operationalLockProvider),
                protection: ref.watch(sensitiveScreenProtectionProvider),
                clock: clock,
                beforeReveal: cache.review,
                builder: (context, activity) =>
                    _CaseContents(cache: cache, caseId: id, clock: clock, recordActivity: activity),
              ),
      ),
    );
  }
}

class _CaseContents extends StatefulWidget {
  const _CaseContents({
    required this.cache,
    required this.caseId,
    required this.clock,
    required this.recordActivity,
  });

  final AssignedCaseCache cache;
  final String caseId;
  final DateTime Function() clock;
  final VoidCallback recordActivity;

  @override
  State<_CaseContents> createState() => _CaseContentsState();
}

class _CaseContentsState extends State<_CaseContents> {
  late final Stream<AssignedCase?> _cases;
  bool _loading = true;
  bool _loadingExact = false;
  bool _exactFailed = false;

  @override
  void initState() {
    super.initState();
    _cases = widget.cache.watch();
    unawaited(_open());
  }

  Future<void> _open() async {
    try {
      await widget.cache.request(widget.caseId);
    } catch (_) {
      // The cache emits only authorized data. A denied or unavailable case stays empty.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openExact() async {
    widget.recordActivity();
    setState(() {
      _loadingExact = true;
      _exactFailed = false;
    });
    try {
      await widget.cache.requestExact(widget.caseId);
    } catch (_) {
      if (mounted) setState(() => _exactFailed = true);
    } finally {
      if (mounted) setState(() => _loadingExact = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    return StreamBuilder<AssignedCase?>(
      stream: _cases,
      builder: (context, snapshot) {
        final value = snapshot.data;
        if (snapshot.hasError ||
            value == null ||
            value.id != widget.caseId ||
            !value.expiresAt.isAfter(widget.clock())) {
          return Center(
            child: _loading && !snapshot.hasError
                ? const CircularProgressIndicator()
                : Text(texts.operationalCaseUnavailable),
          );
        }
        final location = value.location;
        final cell = value.cell;
        final status = switch (value.stage) {
          HelpRequestStage.sent => texts.statusSent,
          HelpRequestStage.seen => texts.emergencyHelpRequestSeen,
          HelpRequestStage.onTheWay => texts.emergencyHelpRequestOnTheWay,
          HelpRequestStage.attended => texts.emergencyHelpRequestAttended,
          HelpRequestStage.referred => texts.emergencyHelpRequestReferred,
          HelpRequestStage.closedWithoutAssistance => texts.emergencyHelpRequestClosed,
        };
        final coordinates = NumberFormat('0.00000', texts.localeName);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: spaced([
            Text(status, style: Theme.of(context).textTheme.titleLarge),
            Text(texts.operationalNeed(value.need)),
            Text(texts.operationalPriority(value.priority)),
            if (cell != null) Text(texts.operationalCell(cell)),
            const SizedBox(height: 16),
            if (value.stage == HelpRequestStage.onTheWay && location == null)
              OutlinedButton(
                onPressed: _loadingExact ? null : _openExact,
                child: Text(texts.operationalOpenExact),
              ),
            if (value.stage == HelpRequestStage.onTheWay && _exactFailed && location == null)
              Text(texts.operationalExactUnavailable),
            if (location != null) ...[
              Text(location.description),
              Text(
                texts.operationalCoordinates(
                  coordinates.format(location.latitude),
                  coordinates.format(location.longitude),
                ),
              ),
            ],
          ]),
        );
      },
    );
  }
}
