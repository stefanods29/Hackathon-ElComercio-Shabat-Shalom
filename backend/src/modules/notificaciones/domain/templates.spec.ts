import { favorTakenMessage, zoneNoticeMessage } from './templates.js';

describe('plantillas privadas', () => {
  it('solo incluye texto genérico e identificadores', () => {
    expect(favorTakenMessage('id')).toEqual({
      title: 'Vecinal',
      body: 'Tienes una actualización',
      data: { tipo: 'favor_tomado', publicacionId: 'id' },
    });
    expect(zoneNoticeMessage('zona').data).toEqual({ tipo: 'aviso_de_zona', zonaId: 'zona' });
  });
});
