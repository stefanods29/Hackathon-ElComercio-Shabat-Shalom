import { Logger } from '@nestjs/common';
import { OutboxRelayLoop } from './outbox-relay-loop.js';

describe('OutboxRelayLoop', () => {
  afterEach(() => {
    vi.useRealTimers();
    vi.restoreAllMocks();
  });

  it('no solapa lotes lentos y espera el lote en curso al cerrar', async () => {
    vi.useFakeTimers();
    let finish!: (value: { published: number; failed: number }) => void;
    const runOnce = vi.fn().mockImplementation(
      () =>
        new Promise((resolve) => {
          finish = resolve;
        }),
    );
    const loop = new OutboxRelayLoop({ runOnce });
    loop.start();
    await vi.advanceTimersByTimeAsync(5000);
    expect(runOnce).toHaveBeenCalledTimes(1);
    let stopped = false;
    const closing = loop.stop().then(() => {
      stopped = true;
    });
    await Promise.resolve();
    expect(stopped).toBe(false);
    finish({ published: 1, failed: 0 });
    await closing;
    await vi.advanceTimersByTimeAsync(5000);
    expect(stopped).toBe(true);
    expect(runOnce).toHaveBeenCalledTimes(1);
  });

  it('un fallo de un lote no detiene las siguientes vueltas', async () => {
    vi.useFakeTimers();
    vi.spyOn(Logger.prototype, 'error').mockImplementation(() => {});
    const runOnce = vi
      .fn()
      .mockRejectedValueOnce(new Error('sin conexión'))
      .mockResolvedValue({ published: 0, failed: 0 });
    const loop = new OutboxRelayLoop({ runOnce });
    loop.start();
    await vi.advanceTimersByTimeAsync(1000);
    expect(runOnce).toHaveBeenCalledTimes(2);
    await loop.stop();
  });
});
