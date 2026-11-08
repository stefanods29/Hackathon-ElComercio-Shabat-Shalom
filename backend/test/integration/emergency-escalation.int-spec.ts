import { sql } from 'kysely';
import { inject, vi } from 'vitest';
import {
  EMERGENCY_ESCALATE_JOB,
  EmergencyJobs,
} from '../../src/modules/emergencias/application/emergency-jobs.js';
import { NOTIFICATION_PORT } from '../../src/modules/notificaciones/application/ports.js';
import type { FakeNotificationAdapter } from '../../src/modules/notificaciones/infrastructure/notification.fake.js';
import { emergencyFixture } from '../support/emergency-fixture.js';

describe('escalamiento de Emergencias con reloj de prueba y PostgreSQL', () => {
  const fixture = emergencyFixture('+5197800000');
  const review = { alta: 120, media: 180, baja: 240 } as const;
  const warningJob = 'emergencias.avisar_plazo';
  const ownerDevice = 'dispositivo-vecino-escalamiento';
  const coordinatorDevice = (id: string) => `dispositivo-coordinacion-${id}`;
  let jobs: EmergencyJobs;
  let push: FakeNotificationAdapter;

  async function progress(id: string) {
    const { rows } = await sql<{
      etapa_escalamiento: number;
      version: number;
      escalar_en: Date | null;
    }>`SELECT etapa_escalamiento, version, escalar_en
        FROM emergencias.pedidos_ayuda WHERE id = ${id}`.execute(fixture.db());
    return rows[0]!;
  }

  async function escalations(id: string) {
    const { rows } = await sql<{ etapa: number; usuario_id: string | null }>`
      SELECT etapa, usuario_id FROM emergencias.escalamientos
      WHERE pedido_id = ${id} ORDER BY etapa`.execute(fixture.db());
    return rows;
  }

  async function deliverEvent(id: string, type: string) {
    // Relay just this test's persisted event. Other suites share the outbox.
    const { rows } = await sql<{ eventoId: string; agregadoId: string; carga: unknown }>`
      SELECT id AS "eventoId", agregado_id AS "agregadoId", carga FROM compartido.outbox
      WHERE agregado_id = ${id} AND tipo = ${type}`.execute(fixture.db());
    expect(rows).toHaveLength(1);
    await fixture.runJob(type, rows[0]);
  }

  beforeAll(async () => {
    await fixture.start(inject('databaseUrl'), {
      EMERGENCY_REVIEW_HIGH_SECONDS: String(review.alta),
      EMERGENCY_REVIEW_MEDIUM_SECONDS: String(review.media),
      EMERGENCY_REVIEW_LOW_SECONDS: String(review.baja),
    });
    jobs = fixture.app().get(EmergencyJobs);
    push = fixture.app().get(NOTIFICATION_PORT);
    await fixture
      .write('post', '/v1/dispositivos', await fixture.tokenFor(fixture.neighbor), {
        token: ownerDevice,
        plataforma: 'android',
      })
      .expect(200);
    for (const id of fixture.coordinators) {
      await fixture
        .write('post', '/v1/dispositivos', await fixture.coordinatorToken(id), {
          token: coordinatorDevice(id),
          plataforma: 'android',
        })
        .expect(200);
    }
  });

  beforeEach(() => {
    push.sent.length = 0;
  });

  afterAll(() => fixture.close());

  it.each(['alta', 'media', 'baja'] as const)(
    'el barrido recupera el escalamiento de prioridad %s al vencer su plazo y no antes',
    async (priority) => {
      const id = await fixture.requestHelp(priority);
      fixture.advance(review[priority] - 1);
      await fixture.runJob(EMERGENCY_ESCALATE_JOB, { pedidoId: id, etapa: 0 });
      await jobs.maintain();
      expect(await progress(id)).toMatchObject({ etapa_escalamiento: 0, version: 1 });
      expect(await escalations(id)).toHaveLength(1); // Stage 0 is the initial assignment.

      fixture.advance(1);
      await jobs.maintain();
      expect(await progress(id)).toMatchObject({ etapa_escalamiento: 1, version: 2 });
      expect((await escalations(id)).map((row) => row.etapa)).toEqual([0, 1]);
    },
  );

  it('el aviso se programa y sale un minuto antes, solo si el pedido sigue sin revisar', async () => {
    const unseen = await fixture.requestHelp('alta');
    const seen = await fixture.requestHelp('alta');
    const assigned = await fixture.initialCoordinator(unseen);

    const enqueue = vi.spyOn(fixture.queue(), 'enqueue');
    try {
      await deliverEvent(unseen, 'emergencias.pedido_creado');
      expect(enqueue).toHaveBeenCalledWith(
        warningJob,
        { pedidoId: unseen, etapa: 0 },
        expect.objectContaining({ delaySeconds: review.alta - 60 }),
      );
    } finally {
      enqueue.mockRestore();
    }
    push.sent.length = 0;

    const operator = await fixture.coordinatorToken(await fixture.initialCoordinator(seen));
    await fixture
      .write('post', `/v1/pedidos-ayuda/${seen}/estado`, operator, {
        estado: 'visto',
        versionVista: 1,
      })
      .expect(200);

    fixture.advance(review.alta - 61);
    await fixture.runJob(warningJob, { pedidoId: unseen, etapa: 0 });
    expect(push.sent).toEqual([]);

    fixture.advance(1);
    await fixture.runJob(warningJob, { pedidoId: unseen, etapa: 0 });
    expect(push.sent).toEqual([
      {
        destination: coordinatorDevice(assigned),
        message: {
          title: 'Vecinal',
          body: 'Tienes una actualización urgente',
          data: { tipo: 'aviso_urgente', avisoId: expect.any(String), casoId: unseen },
        },
      },
    ]);
    push.sent.length = 0;
    await fixture.runJob(warningJob, { pedidoId: seen, etapa: 0 });
    expect(push.sent).toEqual([]);
  });

  it('el mismo trabajo es idempotente, avisa al autor con alternativas y se detiene en tres etapas', async () => {
    const id = await fixture.requestHelp('alta');
    const initial = await fixture.initialCoordinator(id);
    const next = fixture.coordinators.find((coordinator) => coordinator !== initial);
    fixture.advance(review.alta);

    await Promise.all([jobs.escalate(id, 0), jobs.escalate(id, 0)]);
    await fixture.runJob(EMERGENCY_ESCALATE_JOB, { pedidoId: id, etapa: 0 });
    expect(await progress(id)).toMatchObject({ etapa_escalamiento: 1, version: 2 });
    expect(await escalations(id)).toEqual([
      { etapa: 0, usuario_id: initial },
      { etapa: 1, usuario_id: next },
    ]);
    await deliverEvent(id, 'emergencias.pedido_escalado');
    expect(push.sent.filter((item) => item.destination === ownerDevice)).toEqual([
      {
        destination: ownerDevice,
        message: {
          title: 'Vecinal',
          body: 'Tienes una actualización',
          data: { tipo: 'pedido_actualizado', pedidoId: id, alternativas: 'directorio_emergencia' },
        },
      },
    ]);

    for (const etapa of [1, 2, 3]) {
      fixture.advance(review.alta);
      await fixture.runJob(EMERGENCY_ESCALATE_JOB, { pedidoId: id, etapa });
    }
    await jobs.maintain();
    expect(await progress(id)).toEqual({ etapa_escalamiento: 3, version: 4, escalar_en: null });
    expect(await escalations(id)).toEqual([
      { etapa: 0, usuario_id: initial },
      { etapa: 1, usuario_id: next },
      { etapa: 2, usuario_id: null },
      { etapa: 3, usuario_id: null },
    ]);
  });
});
