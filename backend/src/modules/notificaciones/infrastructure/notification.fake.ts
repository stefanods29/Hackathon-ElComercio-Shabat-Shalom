import type { NotificationPort, PushMessage } from '../application/ports.js';

export class FakeNotificationAdapter implements NotificationPort {
  readonly sent: { destination: string; message: PushMessage }[] = [];
  readonly invalidTokens = new Set<string>();
  readonly failingTokens = new Set<string>();

  async sendToToken(token: string, message: PushMessage): Promise<'sent' | 'invalid_token'> {
    if (this.failingTokens.has(token)) throw new Error('Fallo temporal de entrega');
    if (this.invalidTokens.has(token)) return 'invalid_token';
    this.sent.push({ destination: token, message });
    return 'sent';
  }

  async sendToTopic(topic: string, message: PushMessage): Promise<void> {
    this.sent.push({ destination: topic, message });
  }
}
