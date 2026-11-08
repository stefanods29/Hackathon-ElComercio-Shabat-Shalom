import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vecinal/core/di/providers.dart';
import 'package:vecinal/core/router/routes.dart';
import 'package:vecinal/core/time/time_ago.dart';
import 'package:vecinal/core/ui/wrapping_app_bar.dart';
import 'package:vecinal/features/emergencias/data/providers.dart';
import 'package:vecinal/features/emergencias/domain/public_emergency_board.dart';
import 'package:vecinal/features/onboarding/practice_mode.dart';
import 'package:vecinal/l10n/app_localizations.dart';

class PublicEmergencyBoardPage extends ConsumerWidget {
  const PublicEmergencyBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final texts = AppLocalizations.of(context);
    final available =
        ref.watch(practiceModeProvider).asData?.value == false &&
        ref.watch(emergencyBoardRepositoryProvider) != null;
    final practice = ref.watch(practiceModeProvider).asData?.value == true;
    final clock = ref.watch(clockProvider);
    return Scaffold(
      appBar: wrappingAppBar(context, texts.emergencyBoardTitle),
      body: SafeArea(
        child: practice
            ? _BoardList(
                clock: clock,
                snapshot: practiceBoardSnapshot(clock()),
                notice: texts.emergencyBoardPractice,
              )
            : !available
            ? _BoardList(clock: ref.watch(clockProvider), notice: texts.emergencyBoardUnavailable)
            : ref
                  .watch(emergencyBoardProvider)
                  .when(
                    data: (snapshot) =>
                        _BoardList(clock: ref.watch(clockProvider), snapshot: snapshot),
                    loading: () => _BoardList(clock: ref.watch(clockProvider), loading: true),
                    error: (_, _) => _BoardList(
                      clock: ref.watch(clockProvider),
                      notice: texts.emergencyBoardUnavailable,
                    ),
                  ),
      ),
    );
  }
}

class _BoardList extends StatefulWidget {
  const _BoardList({required this.clock, this.snapshot, this.notice, this.loading = false});

  final DateTime Function() clock;
  final PublicEmergencySnapshot? snapshot;
  final String? notice;
  final bool loading;

  @override
  State<_BoardList> createState() => _BoardListState();
}

class _BoardListState extends State<_BoardList> {
  late final AppLifecycleListener _lifecycle;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _schedule();
  }

  @override
  void didUpdateWidget(covariant _BoardList oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _refresh() {
    setState(() {});
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final snapshot = widget.snapshot;
    if (snapshot == null || (snapshot.demands.isEmpty && snapshot.resources.isEmpty)) return;
    final now = widget.clock();
    var delay = const Duration(minutes: 1);
    for (final resource in snapshot.resources) {
      final remaining = resource.staleAt.difference(now);
      if (remaining > Duration.zero && remaining < delay) delay = remaining;
    }
    _timer = Timer(delay, _refresh);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final texts = AppLocalizations.of(context);
    final resources = widget.snapshot?.resources ?? const <PublicCriticalResource>[];
    final demands = widget.snapshot?.demands ?? const <CellDemand>[];
    final now = widget.clock();
    final aggregateHeader = resources.length + 2;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: 3 + resources.length + demands.length,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(texts.emergencyLifeRisk),
              TextButton(
                onPressed: () => context.push(Routes.emergency),
                child: Text(texts.emergencyTitle),
              ),
              if (widget.loading) const LinearProgressIndicator(),
              if (widget.notice case final notice?) Text(notice),
            ],
          );
        }
        if (index == 1) {
          return _heading(
            context,
            texts.emergencyBoardResources,
            widget.snapshot != null && resources.isEmpty ? texts.emergencyBoardNoResources : null,
          );
        }
        if (index == aggregateHeader) {
          return _heading(
            context,
            texts.emergencyBoardDemands,
            widget.snapshot != null && demands.isEmpty ? texts.emergencyBoardNoDemands : null,
          );
        }
        if (index < aggregateHeader) {
          final resource = resources[index - 2];
          final source = resource.source;
          return _card(context, resource.label ?? texts.emergencyBoardCategory(resource.kind), [
            texts.emergencyBoardQuantity(resource.quantity),
            texts.emergencyBoardCell(resource.cell),
            texts.emergencyBoardReported(timeAgo(resource.reportedAt, now, texts)),
            if (resource.isStaleAt(now)) texts.emergencyPossiblyOutdated,
            if (source != null)
              resource.official
                  ? texts.emergencyBoardOfficialSource(source.toString())
                  : texts.emergencyBoardSource(source.toString()),
            if (resource.official) texts.emergencyBoardVerificationDateUnknown,
          ]);
        }
        final demand = demands[index - aggregateHeader - 1];
        return _card(
          context,
          texts.emergencyBoardDemand(demand.count, texts.emergencyBoardCategory(demand.need)),
          [
            texts.emergencyBoardCell(demand.cell),
            texts.updatedAgo(timeAgo(demand.updatedAt, now, texts)),
          ],
        );
      },
    );
  }

  Widget _heading(BuildContext context, String title, String? empty) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (empty != null) Text(empty),
      ],
    ),
  );

  Widget _card(BuildContext context, String title, List<String> details) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          for (final detail in details) Text(detail),
        ],
      ),
    ),
  );
}

/// Fictitious zone board for practice mode: aggregated by cell, never a person or a case.
PublicEmergencySnapshot practiceBoardSnapshot(DateTime now) => PublicEmergencySnapshot(
  resources: [
    PublicCriticalResource(
      id: 'practica-agua',
      kind: 'agua',
      quantity: 40,
      cell: 'A3',
      reportedAt: now.subtract(const Duration(minutes: 35)),
      staleAfter: const Duration(hours: 6),
      verification: 'vecinos',
      confirmations: 3,
      official: false,
      label: 'Bidones de agua en el local comunal (ficticio)',
    ),
    PublicCriticalResource(
      id: 'practica-albergue',
      kind: 'albergue',
      quantity: 25,
      cell: 'B2',
      reportedAt: now.subtract(const Duration(hours: 2)),
      staleAfter: const Duration(hours: 12),
      verification: 'vecinos',
      confirmations: 5,
      official: false,
      label: 'Albergue en el colegio (ficticio)',
    ),
    PublicCriticalResource(
      id: 'practica-medicamentos',
      kind: 'medicamentos',
      quantity: 8,
      cell: 'C1',
      reportedAt: now.subtract(const Duration(hours: 9)),
      staleAfter: const Duration(hours: 6),
      verification: 'sin_verificar',
      confirmations: 0,
      official: false,
    ),
  ],
  demands: [
    CellDemand(
      cell: 'A3',
      need: 'agua',
      count: 6,
      updatedAt: now.subtract(const Duration(minutes: 10)),
    ),
    CellDemand(
      cell: 'B2',
      need: 'albergue',
      count: 2,
      updatedAt: now.subtract(const Duration(minutes: 25)),
    ),
    CellDemand(
      cell: 'C1',
      need: 'traslado',
      count: 1,
      updatedAt: now.subtract(const Duration(hours: 1)),
    ),
  ],
);
