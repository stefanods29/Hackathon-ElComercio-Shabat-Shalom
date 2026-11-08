/** Job that Emergencies (Phase 2, Lot B) enqueues when it assigns or escalates a case. */
export const URGENT_NOTICE_JOB = 'notificaciones.enviar_aviso_urgente';

/** Internal follow-up: after the acknowledgement window, decide whether to send the SMS backup. */
export const URGENT_REVIEW_JOB = 'notificaciones.revisar_aviso_urgente';

export const URGENT_TEMPLATES = ['caso_asignado', 'pedido_por_escalar', 'pedido_escalado'] as const;
export type UrgentTemplate = (typeof URGENT_TEMPLATES)[number];

/** Shared worker contract: JSON keys stay in Spanish. No personal or sensitive data. */
export interface UrgentNoticeJob {
  /** Reusing this id must never send a second notice nor a second SMS. */
  readonly avisoId: string;
  /** Coordinator or brigade member who must react. */
  readonly usuarioId: string;
  readonly plantilla: UrgentTemplate;
  /** Identifiers only: never names, locations, phone numbers, needs or health data. */
  readonly datos: { readonly casoId?: string };
}
