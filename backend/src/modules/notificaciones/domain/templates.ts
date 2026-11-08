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

export function requestUpdatedMessage(pedidoId: string, alternatives = false) {
  const data: Record<string, string> = { tipo: 'pedido_actualizado', pedidoId };
  if (alternatives) data.alternativas = 'directorio_emergencia';
  return { title: 'Vecinal', body: 'Tienes una actualización', data } as const;
}
