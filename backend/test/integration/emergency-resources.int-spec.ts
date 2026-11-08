import { sql } from 'kysely';
import { inject } from 'vitest';
import { EMERGENCY_AGGREGATES_JOB } from '../../src/modules/emergencias/application/emergency-jobs.js';
import { newId } from '../../src/shared/domain/ids.js';
import { emergencyFixture } from '../support/emergency-fixture.js';

describe('concurrencia y supresión de recursos de Emergencias con PostgreSQL', () => {
  const fixture = emergencyFixture('+5197810000');
  const ttl = 600;
  const resources: string[] = [];

  beforeAll(() =>
    fixture.start(inject('databaseUrl'), {
      EMERGENCY_REQUEST_TTL_SECONDS: String(ttl),
      EMERGENCY_REVIEW_HIGH_SECONDS: '120',
      EMERGENCY_REVIEW_MEDIUM_SECONDS: '180',
      EMERGENCY_REVIEW_LOW_SECONDS: '240',
    }),
  );

  afterAll(async () => {
    try {
      await fixture
        .db()
        .transaction()
        .execute(async (tx) => {
          await sql`DELETE FROM emergencias.agregados_celda WHERE zona_id = ${fixture.zoneId}
          AND celda IN (
            SELECT celda FROM emergencias.pedidos_ayuda WHERE evento_id = ${fixture.eventId}
          )`.execute(tx);
          await sql`DELETE FROM emergencias.confirmaciones_recursos
          WHERE recurso_id = ANY(${resources}::uuid[])`.execute(tx);
          await sql`DELETE FROM emergencias.recursos_publicos
          WHERE id = ANY(${resources}::uuid[])`.execute(tx);
          await sql`DELETE FROM emergencias.recursos_criticos
          WHERE id = ANY(${resources}::uuid[])`.execute(tx);
        });
    } finally {
      await fixture.close();
    }
  });

  async function reportResource() {
    const id = newId();
    resources.push(id);
    await fixture
      .write(
        'post',
        `/v1/zonas/${fixture.zoneId}/recursos`,
        await fixture.tokenFor(fixture.neighbor),
        { id, tipo: 'agua', cantidad: 10, ubicacion: fixture.location },
      )
      .expect(200);
    return id;
  }

  it('solo una de dos actualizaciones concurrentes con la misma versión se aplica', async () => {
    const id = await reportResource();
    const path = `/v1/recursos-criticos/${id}`;
    const [reporter, coordinator] = await Promise.all([
      fixture.tokenFor(fixture.neighbor),
      fixture.coordinatorToken(fixture.coordinators[0]!),
    ]);
    const results = await Promise.all([
      fixture.write('patch', path, reporter, { versionVista: 1, cantidad: 12 }),
      fixture.write('patch', path, coordinator, { versionVista: 1, cantidad: 15 }),
    ]);
    expect(results.map((result) => result.status).sort((left, right) => left - right)).toEqual([
      200, 409,
    ]);
    const winner = results.find((result) => result.status === 200)!;
    const conflict = results.find((result) => result.status === 409)!;
    expect(conflict.body.codigo).toBe('conflicto_de_version');
    expect(winner.body).toMatchObject({ id, version: 2 });
    const { rows } = await sql`SELECT cantidad, version FROM emergencias.recursos_criticos
      WHERE id = ${id}`.execute(fixture.db());
    expect(rows).toEqual([{ cantidad: winner.body.cantidad, version: 2 }]);
  });

  it('el mismo vecino solo suma una confirmación y la copia pública no incluye datos del autor', async () => {
    const id = await reportResource();
    const token = await fixture.tokenFor(fixture.otherNeighbor);
    const path = `/v1/recursos-criticos/${id}/confirmaciones`;
    const first = await fixture.write('post', path, token, { versionVista: 1 }).expect(200);
    expect(first.body).toMatchObject({ confirmaciones: 1, version: 2 });
    const second = await fixture.write('post', path, token, { versionVista: 2 }).expect(200);
    expect(second.body).toEqual(first.body);

    const { rows: confirmations } = await sql`SELECT usuario_id
      FROM emergencias.confirmaciones_recursos WHERE recurso_id = ${id}`.execute(fixture.db());
    expect(confirmations).toEqual([{ usuario_id: fixture.otherNeighbor }]);

    const { rows } = await sql<Record<string, unknown>>`SELECT * FROM emergencias.recursos_publicos
      WHERE id = ${id}`.execute(fixture.db());
    expect(rows).toHaveLength(1);
    expect(rows[0]).toMatchObject({ id, confirmaciones: 1, version: 2 });
    expect(rows[0]).not.toHaveProperty('reportante_id');
    expect(rows[0]).not.toHaveProperty('huella');
  });

  it('publica solo grupos de tres o más por necesidad y descuenta cierres y vencimientos', async () => {
    const token = await fixture.tokenFor(fixture.neighbor);
    async function expectSnapshot(count?: number) {
      await fixture.runJob(EMERGENCY_AGGREGATES_JOB);
      const { rows } = await sql`SELECT necesidad, cantidad FROM emergencias.agregados_celda
        WHERE zona_id = ${fixture.zoneId}`.execute(fixture.db());
      expect(rows).toEqual(count === undefined ? [] : [{ necesidad: 'agua', cantidad: count }]);
      const response = await fixture.get(`/v1/zonas/${fixture.zoneId}/celdas`, token).expect(200);
      const updatedAt = fixture.now().toISOString();
      // Match the whole response so a complementary total cannot leak at either level.
      expect(response.body).toEqual({
        actualizadoEn: count === undefined ? null : updatedAt,
        elementos:
          count === undefined
            ? []
            : [
                {
                  id: expect.any(String),
                  limites: {
                    sur: expect.any(Number),
                    oeste: expect.any(Number),
                    norte: expect.any(Number),
                    este: expect.any(Number),
                  },
                  necesidad: 'agua',
                  cantidad: count,
                  actualizadoEn: updatedAt,
                },
              ],
      });
    }

    await fixture.requestHelp('baja');
    await fixture.requestHelp('baja');
    await fixture.requestHelp('baja', 'alimentos');
    await expectSnapshot();

    fixture.advance(1);
    await fixture.requestHelp('baja');
    await expectSnapshot(3);
    const toClose = await fixture.requestHelp('baja');
    await expectSnapshot(4);
    const coordinator = await fixture.coordinatorToken(await fixture.initialCoordinator(toClose));
    const path = `/v1/pedidos-ayuda/${toClose}/estado`;
    await fixture
      .write('post', path, coordinator, { estado: 'visto', versionVista: 1 })
      .expect(200);
    await fixture
      .write('post', path, coordinator, {
        estado: 'cerrado_sin_atender',
        versionVista: 2,
        motivo: 'Cierre ficticio de prueba',
      })
      .expect(200);
    await expectSnapshot(3);

    fixture.advance(ttl - 1);
    // The snapshot itself must suppress expired requests even before the maintenance job runs.
    await expectSnapshot();
  });
});
