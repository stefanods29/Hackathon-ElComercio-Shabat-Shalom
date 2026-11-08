import { JobHandlerRegistry } from './job-handler.registry.js';
import { InMemoryJobQueue } from './job-queue.memory.js';

describe('JobHandlerRegistry', () => {
  it('inicia los manejadores registrados por los módulos', async () => {
    const registry = new JobHandlerRegistry();
    const queue = new InMemoryJobQueue();
    const received: string[] = [];
    registry.register<{ id: string }>('pruebas.aviso', async (data) => {
      received.push(data.id);
    });
    await queue.enqueue('pruebas.aviso', { id: 'aviso-1' });
    await registry.startAll(queue);
    await queue.drain();
    expect(received).toEqual(['aviso-1']);
  });

  it('entrega un evento al dueño y a su suscriptor sin reemplazar al primero', async () => {
    const registry = new JobHandlerRegistry();
    const queue = new InMemoryJobQueue();
    const received: string[] = [];
    registry.subscribe('pruebas.contenido', 'media', async () => {
      received.push('media');
    });
    registry.register('pruebas.contenido', async () => {
      received.push('dueño');
    });
    expect(() => registry.subscribe('pruebas.contenido', 'media', async () => {})).toThrow(
      /duplicado/,
    );
    await registry.startAll(queue);
    await queue.enqueue('pruebas.contenido', {});
    await queue.drain();
    expect(received).toEqual(['dueño', 'media']);
  });

  it('no entrega a suscriptores un evento que el dueño identifica como obsoleto', async () => {
    const registry = new JobHandlerRegistry();
    const queue = new InMemoryJobQueue();
    const subscriber = vi.fn(async () => {});
    registry.register('pruebas.contenido', async () => false);
    registry.subscribe('pruebas.contenido', 'media', subscriber);
    await registry.startAll(queue);
    await queue.enqueue('pruebas.contenido', {});
    await queue.drain();
    expect(subscriber).not.toHaveBeenCalled();
  });

  it('rechaza duplicados y registros tardíos para no reemplazar manejadores sin aviso', async () => {
    const registry = new JobHandlerRegistry();
    registry.register('pruebas.aviso', async () => {});
    expect(() => registry.register('pruebas.aviso', async () => {})).toThrow(/duplicado/);
    await registry.startAll(new InMemoryJobQueue());
    expect(() => registry.register('otro', async () => {})).toThrow(/antes/);
    await expect(registry.startAll(new InMemoryJobQueue())).rejects.toThrow(/iniciados/);
  });
});
