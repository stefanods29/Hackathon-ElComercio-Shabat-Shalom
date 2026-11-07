import { cert, deleteApp, initializeApp, type App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import type { NotificationPort, PushMessage } from '../application/ports.js';

export class FcmNotificationAdapter implements NotificationPort {
  private readonly app: App;

  constructor(serviceAccountBase64: string) {
    const account: { project_id: string; client_email: string; private_key: string } = JSON.parse(
      Buffer.from(serviceAccountBase64, 'base64').toString('utf8'),
    );
    this.app = initializeApp(
      {
        credential: cert({
          projectId: account.project_id,
          clientEmail: account.client_email,
          privateKey: account.private_key,
        }),
      },
      'vecinal-avisos',
    );
  }

  async sendToToken(token: string, message: PushMessage): Promise<'sent' | 'invalid_token'> {
    try {
      // Flutter Messaging 17 registers Firebase Installation IDs; REST keeps the opaque `token` field.
      await this.send({ fid: token }, message);
      return 'sent';
    } catch (error: unknown) {
      if (
        typeof error === 'object' &&
        error !== null &&
        'code' in error &&
        error.code === 'messaging/registration-token-not-registered'
      )
        return 'invalid_token';
      // SDK errors can contain registration tokens. Do not expose them to worker logs.
      throw new Error('No se pudo entregar el aviso mediante Firebase');
    }
  }

  async sendToTopic(topic: string, message: PushMessage): Promise<void> {
    try {
      await this.send({ topic }, message);
    } catch {
      throw new Error('No se pudo entregar el aviso de zona mediante Firebase');
    }
  }

  private async send(
    target: { fid: string } | { topic: string },
    message: PushMessage,
  ): Promise<void> {
    await getMessaging(this.app).send({
      ...target,
      notification: { title: message.title, body: message.body },
      data: { ...message.data },
      android: { priority: 'high' },
    });
  }

  async onModuleDestroy(): Promise<void> {
    await deleteApp(this.app);
  }
}
