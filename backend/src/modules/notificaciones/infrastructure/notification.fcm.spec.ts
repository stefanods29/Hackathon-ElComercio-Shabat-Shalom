import { vi } from 'vitest';
import { FcmNotificationAdapter } from './notification.fcm.js';

const { send } = vi.hoisted(() => ({ send: vi.fn() }));
vi.mock('firebase-admin/app', () => ({
  cert: vi.fn(),
  initializeApp: vi.fn(() => ({})),
  deleteApp: vi.fn(),
}));
vi.mock('firebase-admin/messaging', () => ({ getMessaging: () => ({ send }) }));

describe('adaptador FCM', () => {
  const message = {
    title: 'Vecinal',
    body: 'Tienes una actualización',
    data: { tipo: 'favor_tomado' },
  };
  const adapter = () =>
    new FcmNotificationAdapter(
      Buffer.from(
        JSON.stringify({
          project_id: 'prueba',
          client_email: 'prueba@example.com',
          private_key: 'solo-doble',
        }),
      ).toString('base64'),
    );
  beforeEach(() => {
    send.mockReset();
  });
  it('envía al FID registrado por Flutter 17 y al tópico', async () => {
    const push = adapter();
    expect(await push.sendToToken('instalacion-de-prueba', message)).toBe('sent');
    expect(send).toHaveBeenCalledWith({
      fid: 'instalacion-de-prueba',
      notification: { title: message.title, body: message.body },
      data: message.data,
      android: { priority: 'high' },
    });
    await push.sendToTopic('zona-prueba', message);
    expect(send.mock.lastCall?.[0]).toHaveProperty('topic', 'zona-prueba');
    await push.onModuleDestroy();
  });
  it('retira instalaciones inválidas y oculta los errores del SDK en los demás casos', async () => {
    const push = adapter();
    send.mockRejectedValueOnce({ code: 'messaging/registration-token-not-registered' });
    expect(await push.sendToToken('invalido', message)).toBe('invalid_token');
    send.mockRejectedValueOnce(new Error('error que contiene un token privado'));
    await expect(push.sendToToken('privado', message)).rejects.toThrow(
      /^No se pudo entregar el aviso mediante Firebase$/,
    );
  });
});
