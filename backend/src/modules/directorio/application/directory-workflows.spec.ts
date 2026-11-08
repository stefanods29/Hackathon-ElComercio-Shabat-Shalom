import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { InMemoryOutboxWriter } from '../../../shared/outbox/outbox.memory.js';
import { InMemoryDirectoryRepository } from '../infrastructure/directory.repository.memory.js';
import { Service, type ServiceData } from '../domain/service.js';
import { EditService } from './edit-service.js';
import { PublishService } from './publish-service.js';
import { ReadDirectory } from './read-directory.js';
import { SaveProvider } from './save-provider.js';
import { WithdrawService } from './withdraw-service.js';

const NOW = new Date('2026-11-08T01:00:00Z');
const clock = { now: () => NOW };
const transaction = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(transaction) };
const actor = { id: newId(), zoneId: newId(), trustLevel: 1 };
const profile = { publicName: 'Gasfitería Don Luis', description: null };
const data: ServiceData = {
  categoryId: 'gasfiteria',
  title: 'Arreglo fugas y cambio caños',
  description: null,
  location: { lat: -12.085678, lng: -77.034567 },
  showExactLocation: false,
  coverageRadiusMeters: 2000,
  availableInEmergency: true,
  attributes: {},
};
const command = () => ({ ...data, id: newId() });

async function setup() {
  const directory = new InMemoryDirectoryRepository();
  const outbox = new InMemoryOutboxWriter();
  const save = new SaveProvider(unitOfWork, directory, clock);
  await save.execute(profile, actor);
  return {
    directory,
    outbox,
    save,
    publish: new PublishService(unitOfWork, directory, outbox, clock),
    edit: new EditService(unitOfWork, directory, clock),
    withdraw: new WithdrawService(unitOfWork, directory, clock),
    read: new ReadDirectory(unitOfWork, directory),
  };
}

describe('Casos de uso del directorio', () => {
  it('guarda el perfil propio y lo actualiza sin duplicarlo', async () => {
    const context = await setup();
    const saved = await context.save.execute({ ...profile, publicName: 'Nuevo nombre' }, actor);
    expect(saved).toMatchObject({ id: actor.id, publicName: 'Nuevo nombre', createdAt: NOW });
  });

  it('perfil y publicación exigen nivel 1 y una zona', async () => {
    const context = await setup();
    for (const [changes, code] of [
      [{ trustLevel: 0 }, 'nivel_de_confianza_insuficiente'],
      [{ zoneId: null }, 'sin_zona'],
    ] as const) {
      await expect(context.save.execute(profile, { ...actor, ...changes })).rejects.toMatchObject({
        code,
      });
      await expect(
        context.publish.execute(command(), { ...actor, ...changes }),
      ).rejects.toMatchObject({ code });
    }
  });

  it('crea el servicio y registra el evento con la misma transacción y el reloj fijo', async () => {
    const context = await setup();
    const record = vi.spyOn(context.outbox, 'record');
    const result = await context.publish.execute(command(), actor);
    expect(result).toMatchObject({ created: true, service: { version: 1, createdAt: NOW } });
    expect(record).toHaveBeenCalledWith(transaction, 'directorio', [
      expect.objectContaining({ type: 'directorio.servicio_publicado', occurredAt: NOW }),
    ]);
  });

  it('el mismo id propio devuelve el original sin alterar el cuerpo ni duplicar el evento', async () => {
    const context = await setup();
    const body = command();
    const first = await context.publish.execute(body, actor);
    const retry = await context.publish.execute({ ...body, title: 'Otro título' }, actor);
    expect(retry).toEqual({ service: first.service, created: false });
    expect(context.outbox.recorded).toHaveLength(1);
    await expect(context.publish.execute(body, { ...actor, id: newId() })).rejects.toMatchObject({
      code: 'id_en_uso',
      kind: 'conflict',
    });
  });

  it('reconoce el id insertado por una carrera sin emitir un segundo evento', async () => {
    const context = await setup();
    const body = command();
    vi.spyOn(context.directory, 'insertService').mockImplementationOnce(async (_tx, service) => {
      context.directory.forceService(service.snapshot());
      return false;
    });
    await expect(context.publish.execute(body, actor)).resolves.toMatchObject({ created: false });
    expect(context.outbox.recorded).toHaveLength(0);
  });

  it('exige perfil vigente en la zona y categoría existente', async () => {
    const context = await setup();
    await expect(
      context.publish.execute(command(), { ...actor, id: newId() }),
    ).rejects.toMatchObject({ code: 'recurso_no_encontrado' });
    await expect(
      context.publish.execute({ ...command(), categoryId: 'inexistente' }, actor),
    ).rejects.toMatchObject({ code: 'categoria_invalida' });
    await expect(
      context.publish.execute(command(), { ...actor, zoneId: newId() }),
    ).rejects.toMatchObject({ code: 'recurso_no_encontrado' });
    expect(context.outbox.recorded).toHaveLength(0);
  });

  it('editar comprueba dueño, versión y categoría y detecta la carrera del repositorio', async () => {
    const context = await setup();
    const { service } = await context.publish.execute(command(), actor);
    await expect(
      context.edit.execute(service.id, 1, data, { ...actor, id: newId() }),
    ).rejects.toMatchObject({ code: 'no_eres_el_dueno' });
    const updated = await context.edit.execute(
      service.id,
      1,
      { ...data, title: 'Nuevo título' },
      actor,
    );
    expect(updated).toMatchObject({ version: 2, title: 'Nuevo título' });
    await expect(context.edit.execute(service.id, 1, data, actor)).rejects.toMatchObject({
      code: 'conflicto_de_version',
      currentVersion: 2,
    });
    await expect(
      context.edit.execute(service.id, 2, { ...data, categoryId: 'inexistente' }, actor),
    ).rejects.toMatchObject({ code: 'categoria_invalida' });
    vi.spyOn(context.directory, 'updateService').mockImplementationOnce(async () => {
      context.directory.forceService({ ...updated, version: 3 });
      return false;
    });
    await expect(context.edit.execute(service.id, 2, data, actor)).rejects.toMatchObject({
      code: 'conflicto_de_version',
      currentVersion: 3,
    });
  });

  it('retirar es idempotente, sale del perfil y publicar el mismo id no lo resucita', async () => {
    const context = await setup();
    const body = command();
    await context.publish.execute(body, actor);
    await context.withdraw.execute(body.id, actor);
    await context.withdraw.execute(body.id, actor);
    await expect(context.read.provider(actor.id)).resolves.toMatchObject({ services: [] });
    await expect(context.publish.execute(body, actor)).resolves.toMatchObject({
      created: false,
      service: { deletedAt: NOW, version: 2 },
    });
    await expect(
      context.withdraw.execute(body.id, { ...actor, id: newId() }),
    ).rejects.toMatchObject({ code: 'no_eres_el_dueno' });
    expect(context.outbox.recorded).toHaveLength(1);
  });

  it('el perfil excluye servicios ocultos o de otra zona y no expone proveedores ocultos', async () => {
    const context = await setup();
    for (const changes of [{ hiddenAt: NOW }, { zoneId: newId() }]) {
      const service = Service.create(
        { ...command(), providerId: actor.id, zoneId: actor.zoneId },
        NOW,
      );
      context.directory.forceService({ ...service.snapshot(), ...changes });
    }
    expect((await context.read.provider(actor.id)).services).toEqual([]);
    const saved = await context.save.execute(profile, actor);
    context.directory.forceProvider({ ...saved, hiddenAt: NOW });
    await expect(context.read.provider(actor.id)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
    await expect(context.save.execute(profile, actor)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
  });

  it('editar, retirar y leer explican un recurso inexistente', async () => {
    const context = await setup();
    await expect(context.edit.execute(newId(), 1, data, actor)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
    await expect(context.withdraw.execute(newId(), actor)).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
    await expect(context.read.provider(newId())).rejects.toMatchObject({
      code: 'recurso_no_encontrado',
    });
  });
});
