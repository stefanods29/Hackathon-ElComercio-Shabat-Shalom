export const SEND_NOTIFICATION_JOB = 'notificaciones.enviar_aviso';

/** Shared worker contract: JSON keys stay in Spanish. No personal or sensitive data. */
export interface SendNotificationJob {
  /** Reusing this id must never send a second notification. */
  readonly avisoId: string;
  readonly destino:
    | { readonly tipo: 'usuario'; readonly usuarioId: string }
    | { readonly tipo: 'zona'; readonly zonaId: string };
  readonly plantilla: 'favor_tomado' | 'aviso_de_zona' | 'pedido_actualizado';
  /** Identifiers only: no names, locations, phone numbers or health data. */
  readonly datos: Readonly<Record<string, string>>;
}
