import 'dart:math' as math;

/// Limits of `MetricasDeSincronizacion` in `contracts/openapi.yaml`.
abstract final class SyncTelemetryLimits {
  static const maxCount = 100000;
  static const maxWaitSeconds = 90 * 24 * 60 * 60;
  static const maxSecondsSinceSync = 10 * 365 * 24 * 60 * 60;
  static const maxRejectionCodes = 20;
  static const otherRejections = 'otros';
  static const unknownRejection = 'sin_codigo';
}

/// Nearest-rank percentile, in integers so it never depends on rounding: with 10, 20 and 90
/// seconds, p50 is 20 and p95 is 90. Null without values.
int? nearestRankPercentile(Iterable<int> values, int percentile) {
  assert(percentile > 0 && percentile <= 100);
  final sorted = values.toList()..sort();
  if (sorted.isEmpty) return null;
  final rank = (percentile * sorted.length + 99) ~/ 100;
  return sorted[rank - 1];
}

/// Body of `POST /v1/telemetria/sincronizacion`: aggregated counters only. No ids, phone numbers,
/// content or locations of the neighbor.
class SyncTelemetryReport {
  const SyncTelemetryReport({
    required this.appVersion,
    required this.system,
    required this.periodStart,
    required this.periodEnd,
    required this.pendingUploads,
    required this.confirmedSends,
    required this.sentP50Seconds,
    required this.sentP95Seconds,
    required this.permanentRejections,
    required this.secondsSinceLastSync,
    required this.connectionErrors,
  });

  final String appVersion;

  /// `android` or `ios`.
  final String system;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int pendingUploads;
  final int confirmedSends;
  final int? sentP50Seconds;
  final int? sentP95Seconds;
  final Map<String, int> permanentRejections;
  final int? secondsSinceLastSync;
  final int connectionErrors;

  Map<String, Object?> toJson() => {
    'versionApp': appVersion,
    'sistema': system,
    'periodoInicio': periodStart.toUtc().toIso8601String(),
    'periodoFin': periodEnd.toUtc().toIso8601String(),
    'colaPendientes': pendingUploads,
    'enviosConfirmados': confirmedSends,
    'tiempoHastaEnviadoP50Segundos': sentP50Seconds,
    'tiempoHastaEnviadoP95Segundos': sentP95Seconds,
    'rechazosPermanentes': permanentRejections,
    'segundosDesdeUltimaSincronizacion': secondsSinceLastSync,
    'erroresDeConexion': connectionErrors,
  };
}

/// Builds the report of (`periodStart`, `periodEnd`] from rows of `envios` (`estado`, `creado_en`,
/// `ultimo_intento_en` and `motivo_codigo`). A submission counts in the period where it got its
/// final answer; the wait goes from "Guardado en tu celular" to "Enviado".
SyncTelemetryReport buildSyncTelemetryReport({
  required Iterable<Map<String, Object?>> submissions,
  required DateTime periodStart,
  required DateTime periodEnd,
  required int pendingUploads,
  required DateTime? lastSyncedAt,
  required int connectionErrors,
  required String appVersion,
  required String system,
}) {
  final waits = <int>[];
  var sent = 0;
  final rejections = <String, int>{};
  for (final row in submissions) {
    final answeredAt = DateTime.tryParse(row['ultimo_intento_en'] as String? ?? '');
    if (answeredAt == null || !answeredAt.isAfter(periodStart) || answeredAt.isAfter(periodEnd)) {
      continue;
    }
    switch (row['estado']) {
      case 'sent':
        sent++;
        final createdAt = DateTime.tryParse(row['creado_en'] as String? ?? '');
        if (createdAt != null) {
          final seconds = answeredAt.difference(createdAt).inSeconds;
          waits.add(math.min(math.max(seconds, 0), SyncTelemetryLimits.maxWaitSeconds));
        }
      case 'couldNotComplete':
        final code = rejectionCode(row['motivo_codigo'] as String?);
        rejections[code] = (rejections[code] ?? 0) + 1;
    }
  }
  final sinceSync = lastSyncedAt == null
      ? null
      : math.min(
          math.max(periodEnd.difference(lastSyncedAt).inSeconds, 0),
          SyncTelemetryLimits.maxSecondsSinceSync,
        );
  return SyncTelemetryReport(
    appVersion: appVersion,
    system: system,
    periodStart: periodStart,
    periodEnd: periodEnd,
    pendingUploads: _capped(pendingUploads),
    confirmedSends: _capped(sent),
    sentP50Seconds: nearestRankPercentile(waits, 50),
    sentP95Seconds: nearestRankPercentile(waits, 95),
    permanentRejections: _limitCodes(rejections),
    secondsSinceLastSync: sinceSync,
    connectionErrors: _capped(connectionErrors),
  );
}

/// The problem code (`resena_duplicada`, `validacion`…) in the contract's alphabet.
String rejectionCode(String? code) {
  final cleaned = (code ?? '').toLowerCase().replaceAll(RegExp('[^a-z0-9_]'), '_');
  if (cleaned.isEmpty) return SyncTelemetryLimits.unknownRejection;
  return cleaned.length > 64 ? cleaned.substring(0, 64) : cleaned;
}

int _capped(int value) => math.min(math.max(value, 0), SyncTelemetryLimits.maxCount);

/// At most 20 codes: the 19 most frequent and the rest added under `otros`.
Map<String, int> _limitCodes(Map<String, int> rejections) {
  if (rejections.length <= SyncTelemetryLimits.maxRejectionCodes) {
    return {for (final MapEntry(:key, :value) in rejections.entries) key: _capped(value)};
  }
  final sorted = rejections.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  final kept = sorted.take(SyncTelemetryLimits.maxRejectionCodes - 1);
  final rest = sorted
      .skip(SyncTelemetryLimits.maxRejectionCodes - 1)
      .fold<int>(0, (total, entry) => total + entry.value);
  final limited = {for (final entry in kept) entry.key: _capped(entry.value)};
  limited[SyncTelemetryLimits.otherRejections] = _capped(
    (limited[SyncTelemetryLimits.otherRejections] ?? 0) + rest,
  );
  return limited;
}
