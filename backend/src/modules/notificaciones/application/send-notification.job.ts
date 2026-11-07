export const SEND_NOTIFICATION_JOB = 'notificaciones.enviar_aviso';

/** Contract shared with the Lot B outbox relay. No personal text enters the queue. */
export interface SendNotificationJob {
  readonly avisoId: string;
  readonly destino:
    | { readonly tipo: 'usuario'; readonly usuarioId: string }
    | { readonly tipo: 'zona'; readonly zonaId: string };
  readonly plantilla: 'favor_tomado' | 'aviso_de_zona';
  readonly datos: Readonly<Record<string, string>>;
}
