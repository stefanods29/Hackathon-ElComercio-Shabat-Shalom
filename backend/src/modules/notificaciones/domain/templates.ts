/** Lock-screen text stays generic, including zone broadcasts until the coordinator API exists. */
export function favorTakenMessage(publicacionId: string) {
  return {
    title: 'Vecinal',
    body: 'Tienes una actualización',
    data: { tipo: 'favor_tomado', publicacionId },
  } as const;
}

export function zoneNoticeMessage(zonaId: string) {
  return {
    title: 'Vecinal',
    body: 'Hay una actualización pública en tu zona',
    data: { tipo: 'aviso_de_zona', zonaId },
  } as const;
}

/** Public information only: the zone topic reaches every phone subscribed to the zone. */
export function emergencyActivatedMessage(zonaId: string) {
  return {
    title: 'Vecinal',
    body: 'Se activó el modo emergencia en tu zona. Abre la app para ver qué hacer.',
    data: { tipo: 'modo_emergencia_activado', zonaId },
  } as const;
}

/**
 * Every urgent template shares the same lock-screen text: the case, the need and the people
 * involved are seen inside the app or the console, after signing in.
 */
export function urgentNoticeMessage(avisoId: string, casoId?: string) {
  const data: Record<string, string> = { tipo: 'aviso_urgente', avisoId };
  if (casoId) data.casoId = casoId;
  return { title: 'Vecinal', body: 'Tienes una actualización urgente', data };
}

/** SMS backup text: generic, with no link that could be spoofed and no case details. */
export const URGENT_SMS_TEXT = 'Vecinal: tienes una actualización urgente. Abre la app para verla.';
