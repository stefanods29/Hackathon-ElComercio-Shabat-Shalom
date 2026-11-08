import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { JobHandlerRegistry } from '../../../shared/queues/job-handler.registry.js';
import { InMemoryJobQueue } from '../../../shared/queues/job-queue.memory.js';
import { InMemoryDirectoryRepository } from '../infrastructure/directory.repository.memory.js';
import { Service } from '../domain/service.js';
import { ZoneChangedHandler, ZONE_CHANGED_EVENT } from './zone-changed-handler.js';

const NOW = new Date('2026-11-08T01:00:00Z');
const clock = { now: () => NOW };
const transaction = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(transaction) };

it('la cola retira solo los servicios de la zona anterior y repetir el evento no los cambia', async () => {
  const directory = new InMemoryDirectoryRepository();
  const registry = new JobHandlerRegistry();
  const queue = new InMemoryJobQueue(clock);
  const handler = new ZoneChangedHandler(registry, unitOfWork, directory, clock);
  handler.onModuleInit();
  await registry.startAll(queue);
  const owner = newId();
  const previousZone = newId();
  const nextZone = newId();
  const services = [
    [owner, previousZone],
    [owner, previousZone],
    [owner, nextZone],
    [newId(), previousZone],
  ].map(([providerId, zoneId]) =>
    Service.create(
      {
        id: newId(),
        providerId: providerId!,
        zoneId: zoneId!,
        categoryId: 'gasfiteria',
        title: 'Gasfitería a domicilio',
        description: null,
        location: { lat: -12, lng: -77 },
        showExactLocation: false,
        coverageRadiusMeters: 2000,
        availableInEmergency: true,
        attributes: {},
      },
      NOW,
    ),
  );
  for (const service of services) await directory.insertService(transaction, service);
  const event = {
    eventoId: newId(),
    modulo: 'identidad',
    agregadoId: owner,
    ocurridoEn: NOW.toISOString(),
    carga: { zonaAnteriorId: previousZone, zonaId: nextZone },
  };
  for (let attempt = 0; attempt < 2; attempt += 1) {
    await queue.enqueue(ZONE_CHANGED_EVENT, event);
    await queue.drain();
    for (const [index, service] of services.entries()) {
      const saved = (await directory.findService(transaction, service.id))!.snapshot();
      expect(saved.deletedAt).toEqual(index < 2 ? NOW : null);
      expect(saved.version).toBe(index < 2 ? 2 : 1);
    }
  }
  expect(await directory.listPublicServices(transaction, owner, previousZone)).toEqual([]);
  expect(await directory.listPublicServices(transaction, owner, nextZone)).toHaveLength(1);
});

it('rechaza un evento sin la zona anterior antes de modificar servicios', async () => {
  const directory = new InMemoryDirectoryRepository();
  const withdraw = vi.spyOn(directory, 'withdrawInZone');
  const handler = new ZoneChangedHandler(new JobHandlerRegistry(), unitOfWork, directory, clock);
  await expect(handler.handle({ agregadoId: newId(), carga: {} })).rejects.toThrow();
  expect(withdraw).not.toHaveBeenCalled();
});
