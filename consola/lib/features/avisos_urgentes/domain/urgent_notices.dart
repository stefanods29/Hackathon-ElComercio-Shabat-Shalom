/// Urgent notices of this change (`/v1/avisos-urgentes`): a generic push to a coordinator or
/// brigadist, with an SMS backup if it is not confirmed in time.
library;

enum UrgentTemplate {
  caseAssigned('caso_asignado'),
  aboutToEscalate('pedido_por_escalar'),
  escalated('pedido_escalado');

  const UrgentTemplate(this.code);

  final String code;

  static UrgentTemplate? fromCode(String code) {
    for (final template in values) {
      if (template.code == code) return template;
    }
    return null;
  }
}

class UrgentNotice {
  const UrgentNotice({
    required this.id,
    required this.template,
    required this.caseId,
    required this.createdAt,
  });

  final String id;
  final UrgentTemplate template;
  final String? caseId;
  final DateTime createdAt;
}

/// Totals of `GET /v1/operacion/avisos-urgentes/resumen` (amounts in US cents).
class UrgentNoticeSummary {
  const UrgentNoticeSummary({
    required this.since,
    required this.until,
    required this.smsProvider,
    required this.total,
    required this.confirmed,
    required this.unconfirmed,
    required this.smsSent,
    required this.withoutBackup,
    required this.confirmationP50Seconds,
    required this.confirmationP95Seconds,
    required this.todayCents,
    required this.monthCents,
    required this.dailyCapCents,
    required this.monthlyCapCents,
  });

  final DateTime since;
  final DateTime until;

  /// `none` (backup off) or `fake` (no real message is sent).
  final String smsProvider;
  final int total;
  final int confirmed;
  final int unconfirmed;
  final int smsSent;

  /// By reason: `tope_de_gasto`, `sin_proveedor`, `sin_telefono`, `sms_fallido`.
  final Map<String, int> withoutBackup;
  final int? confirmationP50Seconds;
  final int? confirmationP95Seconds;
  final int todayCents;
  final int monthCents;
  final int dailyCapCents;
  final int monthlyCapCents;
}

abstract interface class UrgentNoticesRepository {
  /// This person's notices of the last day that were not confirmed yet.
  Future<List<UrgentNotice>> pending();

  Future<void> confirm(String noticeId, {required String idempotencyKey});

  Future<UrgentNoticeSummary> summary({DateTime? since});
}
