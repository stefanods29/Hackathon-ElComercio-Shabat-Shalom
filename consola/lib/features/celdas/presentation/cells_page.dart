import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vecinal_consola/core/time/clock.dart';
import 'package:vecinal_consola/core/ui/common.dart';
import 'package:vecinal_consola/features/casos/domain/emergency_case.dart';
import 'package:vecinal_consola/features/casos/presentation/case_labels.dart';
import 'package:vecinal_consola/features/celdas/data/cells_providers.dart';
import 'package:vecinal_consola/features/celdas/domain/cells.dart';
import 'package:vecinal_consola/features/celdas/presentation/cells_map.dart';
import 'package:vecinal_consola/l10n/app_localizations.dart';

/// Aggregates by public cell: the map and a table with the same data for screen readers.
class CellsPage extends ConsumerStatefulWidget {
  const CellsPage({super.key});

  @override
  ConsumerState<CellsPage> createState() => _CellsPageState();
}

class _CellsPageState extends ConsumerState<CellsPage> {
  /// Null: every need together.
  EmergencyNeed? _need;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (ref.watch(cellsRepositoryProvider) == null) {
      return ConsolePage(
        title: l10n.cellsTitle,
        child: ModuleUnavailable(message: l10n.cellsUnavailable),
      );
    }
    final cells = ref.watch(cellsProvider);
    final latest = cells.value;
    return PollWhileVisible(
      interval: const Duration(minutes: 1),
      onTick: () => ref.invalidate(cellsProvider),
      child: ConsolePage(
        title: l10n.cellsTitle,
        subtitle: latest == null ? null : l10n.updatedAt(formatClock(latest.updatedAt)),
        actions: [
          OutlinedButton.icon(
            onPressed: () => ref.invalidate(cellsProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.refresh),
          ),
        ],
        child: AsyncBody(
          value: cells,
          onRetry: () => ref.invalidate(cellsProvider),
          data: (snapshot) => ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              InfoCard(icon: Icons.privacy_tip_outlined, title: l10n.cellsPrivacyNote),
              const SizedBox(height: 16),
              ChoiceRow<EmergencyNeed?>(
                label: l10n.cellsNeedFilter,
                options: const [null, ...EmergencyNeed.values],
                selected: _need,
                labelOf: (need) => need == null ? l10n.cellsAllNeeds : needLabel(l10n, need),
                onSelected: (need) => setState(() => _need = need),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 380,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CellsMap(cells: snapshot.cells, need: _need, label: l10n.cellsMapLabel),
                ),
              ),
              const SizedBox(height: 4),
              Text(l10n.mapAttribution, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              const _Legend(),
              SectionHeading(l10n.cellsTableTitle),
              _CellsTable(cells: snapshot.cells),
            ],
          ),
        ),
      ),
    );
  }
}

String countText(AppLocalizations l10n, CellCount count) =>
    count.value?.toString() ?? l10n.cellsFewerThanThree;

String levelLabel(AppLocalizations l10n, CellLevel level) => switch (level) {
  CellLevel.belowThreshold => l10n.cellsFewerThanThree,
  CellLevel.low => l10n.cellsLevelLow,
  CellLevel.medium => l10n.cellsLevelMedium,
  CellLevel.high => l10n.cellsLevelHigh,
};

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final outline = Theme.of(context).colorScheme.outline;
    return Semantics(
      container: true,
      label: l10n.cellsLegend,
      child: Wrap(
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final level in CellLevel.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: cellLevelColors[level],
                    border: Border.all(color: outline),
                  ),
                ),
                const SizedBox(width: 8),
                Text(levelLabel(l10n, level)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CellsTable extends StatelessWidget {
  const _CellsTable({required this.cells});

  final List<CellAggregate> cells;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (cells.isEmpty) return InfoCard(icon: Icons.grid_off_outlined, title: l10n.cellsEmpty);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowHeight: 56,
        dataRowMinHeight: 48,
        dataRowMaxHeight: double.infinity,
        columns: [
          DataColumn(label: Text(l10n.cellsColumnCell)),
          DataColumn(label: Text(l10n.cellsColumnTotal)),
          for (final need in EmergencyNeed.values) DataColumn(label: Text(needLabel(l10n, need))),
        ],
        rows: [
          for (final cell in cells)
            DataRow(
              cells: [
                DataCell(Text(cell.label)),
                DataCell(Text(countText(l10n, cell.total))),
                for (final need in EmergencyNeed.values)
                  DataCell(Text(countText(l10n, cell.countFor(need)))),
              ],
            ),
        ],
      ),
    );
  }
}
