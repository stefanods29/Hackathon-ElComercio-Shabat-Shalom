import { randomInt } from 'node:crypto';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import type { INestApplication } from '@nestjs/common';
import {
  PowerSyncDatabase,
  Schema,
  Table,
  column,
  type SyncStreamSubscription,
} from '@powersync/node';
import { sql } from 'kysely';
import { PILOT_ZONE } from '../../scripts/seed-data.js';
import type { Role } from '../../src/shared/auth/actor.js';
import { TokenService } from '../../src/shared/auth/token.service.js';
import { createKysely } from '../../src/shared/db/connection.js';
import { newId } from '../../src/shared/domain/ids.js';
import { createTestApp } from '../support/app.js';

const schema = new Schema({
  zonas: new Table({ nombre: column.text }),
  pedidos_ayuda: new Table({ estado: column.text, celda: column.text }),
  ubicaciones_casos: new Table({ descripcion: column.text, lat: column.real, lng: column.real }),
  mis_pedidos_ayuda: new Table({ estado: column.text }),
  historial_mis_pedidos: new Table({ hasta: column.text }),
  detalles_pedidos: new Table({ descripcion: column.text }),
  autorizaciones_stream: new Table({ sesion_id: column.text }),
});

// Assertions deliberately never include actual row values, URLs, credentials or private fixtures.
class SafeFailure extends Error {}
function check(condition: unknown, message: string): asserts condition {
  if (!condition) throw new SafeFailure(message);
}

const bounded = <T>(promise: Promise<T>, label: string): Promise<T> =>
  new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new SafeFailure(`Tiempo agotado: ${label}`)), 45_000);
    promise.then(
      (value) => {
        clearTimeout(timer);
        resolve(value);
      },
      () => {
        clearTimeout(timer);
        reject(new SafeFailure(`Operación rechazada: ${label}`));
      },
    );
  });

it('PowerSync real: permisos por sesión, minimización, revocación y cierre', async () => {
  const databaseUrl = process.env.DATABASE_URL;
  check(databaseUrl, 'Define DATABASE_URL de la base de laboratorio que replica PowerSync.');
  check(
    process.env.POWERSYNC_LIVE_TEST === '1',
    'Define POWERSYNC_LIVE_TEST=1 solo en laboratorio.',
  );
  const localDatabase = URL.parse(databaseUrl);
  check(
    localDatabase &&
      ['postgres:', 'postgresql:'].includes(localDatabase.protocol) &&
      ['localhost', '127.0.0.1', '[::1]'].includes(localDatabase.hostname),
    'La base de laboratorio debe ser local.',
  );
  const endpoint = process.env.POWERSYNC_URL ?? 'http://localhost:8080';
  const localEndpoint = URL.parse(endpoint);
  check(
    localEndpoint && ['localhost', '127.0.0.1', '[::1]'].includes(localEndpoint.hostname),
    'PowerSync debe ser local.',
  );
  const port = Number(process.env.POWERSYNC_TEST_API_PORT ?? '3001');
  check(
    Number.isInteger(port) && port > 0 && port < 65536,
    'El puerto de la API de laboratorio debe ser válido.',
  );
  const api = `http://127.0.0.1:${port}`;
  const db = createKysely(databaseUrl, 3);
  const directory = await mkdtemp(join(tmpdir(), 'vecinal-live-sync-'));
  const zoneId = newId();
  const eventId = newId();
  const caseId = newId();
  const accounts = Array.from({ length: 5 }, () => ({
    id: newId(),
    phone: `+519${randomInt(100_000_000, 999_999_999)}`,
    session: newId(),
  }));
  const [admin, coordinator, backup, first, second] = accounts;
  const owner = {
    id: newId(),
    phone: `+519${randomInt(100_000_000, 999_999_999)}`,
    session: newId(),
  };
  const secondSession = newId();
  const clients: PowerSyncDatabase[] = [];
  const subscriptions: SyncStreamSubscription[] = [];
  const startedAt = Date.now();
  let app: INestApplication | undefined;
  let phase = 'preparación';
  let tokens: TokenService;
  const minutes = (offset: number) => new Date(Date.now() + offset * 60_000).toISOString();
  const location = { lat: -12.085, lng: -77.035 };
  const description = 'Contenido sintético reservado para el laboratorio';
  let marker = 0;

  async function access(account: typeof owner, roles: Role[], session = account.session) {
    return (
      await tokens.issueAccess({ id: account.id, zoneId, trustLevel: 3, roles, sessionId: session })
    ).token;
  }
  async function call(path: string, token: string, body?: object, expected = 200) {
    const response = await fetch(`${api}/v1${path}`, {
      signal: AbortSignal.timeout(20_000),
      method: body ? 'POST' : 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': newId(),
      },
      ...(body ? { body: JSON.stringify(body) } : {}),
    });
    check(response.status === expected, `HTTP inesperado en ${phase}: ${response.status}`);
    return (await response.json()) as Record<string, unknown>;
  }
  async function version() {
    const { rows } = await sql<{
      version: number;
    }>`SELECT version FROM emergencias.pedidos_ayuda WHERE id = ${caseId}`.execute(db);
    return rows[0]!.version;
  }
  async function count(client: PowerSyncDatabase, table: string) {
    const rows = await client.getAll<{ n: number }>(`SELECT count(*) AS n FROM ${table}`);
    return rows[0]!.n;
  }
  async function subscribe(client: PowerSyncDatabase, stream: string, authorizationId: string) {
    const subscription = await client
      .syncStream(stream, { pedido_id: caseId, autorizacion_id: authorizationId })
      .subscribe({ ttl: 0 });
    subscriptions.push(subscription);
    // Match parameter values, not JSON key order (the service may reorder object keys).
    await bounded(
      client.waitForStatus(
        (status) =>
          status.syncStreams?.some(
            ({ subscription: entry }) =>
              entry.name === stream &&
              entry.parameters?.pedido_id === caseId &&
              entry.parameters?.autorizacion_id === authorizationId &&
              entry.hasSynced,
          ),
        AbortSignal.timeout(45_000),
      ),
      `primera sincronización ${stream}, cliente ${clients.indexOf(client)}`,
    );
  }
  async function open(account: typeof owner, scope: 'resumen' | 'exacta') {
    const result = await call(
      `/pedidos-ayuda/${caseId}/accesos-sincronizacion`,
      await access(account, ['brigadista']),
      { alcance: scope },
    );
    check(typeof result.autorizacionId === 'string', 'La API debe devolver el permiso.');
    return result.autorizacionId;
  }
  async function phone(account: typeof owner, roles: Role[], session = account.session) {
    const local = new PowerSyncDatabase({
      schema,
      database: { dbFilename: join(directory, `phone-${clients.length}.db`), readWorkerCount: 1 },
      logger: { log() {} },
    });
    clients.push(local);
    await local.init();
    await local.connect(
      {
        fetchCredentials: async () => {
          const credentials = await call(
            '/sync/credenciales',
            await access(account, roles, session),
          );
          check(typeof credentials.token === 'string', 'La API debe emitir credenciales.');
          const actor = await tokens.verify(credentials.token, 'powersync');
          check(actor.sessionId === session, 'Las credenciales deben conservar sid.');
          return { endpoint, token: credentials.token };
        },
        uploadData: async () => {
          throw new Error('Los clientes de esta prueba son de solo lectura.');
        },
      },
      { includeDefaultStreams: true, checkpointMode: 'requests' },
    );
    await bounded(local.waitForFirstSync(), 'primera sincronización del celular');
    return local;
  }
  // A service checkpoint confirms that every client has applied server changes. A public row
  // written AFTER a mutation additionally proves that the replica is current. Never use sleep
  // as evidence for a zero-row assertion.
  async function barrier() {
    const value = `laboratorio-${++marker}`;
    await sql`UPDATE identidad.zonas SET nombre = ${value}, actualizado_en = now() WHERE id = ${zoneId}`.execute(
      db,
    );
    await Promise.all(
      clients.map(async (client) => {
        const checkpoint = await bounded(client.requestCheckpoint(), 'solicitud de checkpoint');
        await bounded(
          checkpoint.waitForSync({ signal: AbortSignal.timeout(45_000) }),
          'aplicación del checkpoint',
        );
      }),
    );
    await Promise.all(
      clients.map(async (client) => {
        const deadline = Date.now() + 45_000;
        for (;;) {
          const rows = await client.getAll<{ nombre: string }>(
            'SELECT nombre FROM zonas WHERE id = ?',
            [zoneId],
          );
          if (rows[0]?.nombre === value) return;
          check(Date.now() < deadline, 'Tiempo agotado: barrera de replicación.');
          await new Promise((resolve) => setTimeout(resolve, 50));
        }
      }),
    );
  }
  try {
    ({ app } = await createTestApp(databaseUrl, {
      EMERGENCIES_ENABLED: 'true',
      POWERSYNC_URL: endpoint,
      JWT_KID: `live-${newId()}`,
      SMS_PROVIDER: 'fake',
    }));
    tokens = app.get(TokenService);
    await app.listen(port, '0.0.0.0');
    await sql`INSERT INTO identidad.zonas (id,nombre,distrito,limite)
      SELECT ${zoneId}, 'Laboratorio', distrito, limite FROM identidad.zonas WHERE id = ${PILOT_ZONE.id}`.execute(
      db,
    );
    for (const account of [...accounts, owner]) {
      await sql`INSERT INTO identidad.usuarios(id,telefono,nombre_visible,zona_id,nivel_confianza,roles)
        VALUES (${account.id},${account.phone},'Cuenta de laboratorio',${zoneId},3,${account === admin ? ['administrador'] : []})`.execute(
        db,
      );
      await sql`INSERT INTO identidad.sesiones(usuario_id,familia_id,refresh_hash,expira_en)
        VALUES (${account.id},${account.session},${newId()},${minutes(120)}::timestamptz)`.execute(
        db,
      );
    }
    await sql`INSERT INTO identidad.sesiones(usuario_id,familia_id,refresh_hash,expira_en)
      VALUES (${first!.id},${secondSession},${newId()},${minutes(120)}::timestamptz)`.execute(db);
    for (const [account, role] of [
      [coordinator!, 'coordinador'],
      [backup!, 'coordinador'],
      [first!, 'brigadista'],
      [second!, 'brigadista'],
    ] as const) {
      await call('/operacion/habilitaciones', await access(admin!, ['administrador']), {
        id: newId(),
        usuarioId: account.id,
        zonaId: zoneId,
        rol: role,
        dniRevisadoEn: minutes(-60),
        capacitacionEn: minutes(-60),
        confidencialidadEn: minutes(-60),
        referenciaRevision: 'Revisión de laboratorio',
        venceEn: minutes(1440),
      });
    }
    for (const [account, role] of [
      [coordinator!, 'coordinador'],
      [first!, 'brigadista'],
      [second!, 'brigadista'],
    ] as const) {
      await call(`/operacion/zonas/${zoneId}/turnos`, await access(coordinator!, ['coordinador']), {
        id: newId(),
        usuarioId: account.id,
        rol: role,
        inicio: minutes(-5),
        fin: minutes(120),
      });
    }
    await call(`/zonas/${zoneId}/eventos`, await access(coordinator!, ['coordinador']), {
      id: eventId,
      nivel: 2,
    });
    await call('/pedidos-ayuda', await access(owner, []), {
      id: caseId,
      eventoId: eventId,
      necesidad: 'agua',
      prioridad: 'alta',
      descripcion: description,
      ubicacion: location,
    });
    await call(
      `/pedidos-ayuda/${caseId}/asignaciones`,
      await access(coordinator!, ['coordinador']),
      { versionVista: await version(), usuarioId: coordinator!.id, rol: 'coordinador' },
    );
    const one = await phone(first!, ['brigadista']);
    const two = await phone(second!, ['brigadista']);
    const sameAccount = await phone(first!, ['brigadista'], secondSession);
    const author = await phone(owner, []);
    const automatic = await phone(first!, ['brigadista']);
    await barrier();
    check(
      (await count(author, 'mis_pedidos_ayuda')) === 0 &&
        (await count(author, 'historial_mis_pedidos')) === 0,
      'El autor tampoco recibe su pedido sin suscripción explícita.',
    );

    phase = '2.1 sin asignación';
    const forged = newId();
    await subscribe(one, 'caso_asignado', forged);
    await barrier();
    check((await count(one, 'pedidos_ayuda')) === 0, 'Sin asignación no debe llegar resumen.');
    process.stdout.write('PASS 2.1: sin asignación, cero filas\n');

    phase = '2.2 asignación sin permiso';
    await call(`/pedidos-ayuda/${caseId}/estado`, await access(coordinator!, ['coordinador']), {
      versionVista: await version(),
      estado: 'visto',
    });
    await call(
      `/pedidos-ayuda/${caseId}/asignaciones`,
      await access(coordinator!, ['coordinador']),
      { versionVista: await version(), usuarioId: first!.id, rol: 'brigadista' },
    );
    await barrier();
    check(
      (await count(one, 'pedidos_ayuda')) === 0,
      'La asignación sola no autoriza una suscripción directa.',
    );
    const summary = await open(first!, 'resumen');
    await subscribe(one, 'caso_asignado', summary);
    await subscribe(sameAccount, 'caso_asignado', summary);
    await subscribe(two, 'caso_asignado', summary);
    await barrier();
    check(
      (await count(one, 'pedidos_ayuda')) === 1,
      'El permiso de resumen debe entregar una fila.',
    );
    check((await count(sameAccount, 'pedidos_ayuda')) === 0, 'Otra sesión no hereda el permiso.');
    check((await count(two, 'pedidos_ayuda')) === 0, 'Otra cuenta no hereda el permiso.');
    process.stdout.write('PASS 2.2: asignación, cuenta, sesión y permiso independientes\n');

    phase = '2.1 antes de en camino';
    await subscribe(one, 'caso_ubicacion_exacta', summary);
    await call(
      `/pedidos-ayuda/${caseId}/accesos-sincronizacion`,
      await access(first!, ['brigadista']),
      { alcance: 'exacta' },
      409,
    );
    await barrier();
    check(
      (await count(one, 'ubicaciones_casos')) === 0,
      'Un permiso de resumen no entrega ubicación antes de en camino.',
    );
    process.stdout.write('PASS 2.1: antes de en camino, cero ubicaciones\n');

    phase = '2.1 en camino';
    await call(`/pedidos-ayuda/${caseId}/estado`, await access(first!, ['brigadista']), {
      versionVista: await version(),
      estado: 'en_camino',
    });
    await barrier();
    check(
      (await count(one, 'ubicaciones_casos')) === 0,
      'El permiso de resumen tampoco entrega ubicación en camino.',
    );
    const exact = await open(first!, 'exacta');
    await subscribe(one, 'caso_ubicacion_exacta', exact);
    await subscribe(sameAccount, 'caso_ubicacion_exacta', exact);
    await subscribe(two, 'caso_ubicacion_exacta', exact);
    await subscribe(author, 'caso_ubicacion_exacta', exact);
    await subscribe(author, 'mi_pedido', newId());
    await barrier();
    const locations = await one.getAll<{ lat: number; lng: number; descripcion: string }>(
      'SELECT lat,lng,descripcion FROM ubicaciones_casos',
    );
    check(
      locations.length === 1 &&
        locations[0]!.lat === location.lat &&
        locations[0]!.lng === location.lng &&
        locations[0]!.descripcion === description,
      'El permiso exacto debe entregar la proyección esperada.',
    );
    for (const client of [sameAccount, two, author])
      check(
        (await count(client, 'ubicaciones_casos')) === 0,
        'Solo la sesión autorizada recibe ubicación.',
      );
    check(
      (await count(author, 'mis_pedidos_ayuda')) === 1,
      'El stream del autor debe estar sincronizado.',
    );
    process.stdout.write(
      'PASS 2.1 y privacidad: ubicación exacta solo para sesión y alcance autorizados\n',
    );

    phase = 'privacidad automática';
    await barrier();
    for (const table of [
      'pedidos_ayuda',
      'ubicaciones_casos',
      'mis_pedidos_ayuda',
      'historial_mis_pedidos',
      'detalles_pedidos',
      'autorizaciones_stream',
    ])
      check(
        (await count(automatic, table)) === 0,
        'Los streams automáticos no entregan filas privadas de emergencias.',
      );
    const { rows: publication } = await sql<{
      n: number;
    }>`SELECT count(*)::int n FROM pg_publication_tables WHERE pubname='powersync' AND schemaname='emergencias' AND tablename='detalles_pedidos'`.execute(
      db,
    );
    check(publication[0]!.n === 0, 'Los detalles privados deben quedar fuera de la publicación.');
    process.stdout.write(
      'PASS privacidad: automáticos sin filas sensibles y detalles fuera de publicación\n',
    );
    await subscribe(automatic, 'caso_asignado', exact);
    await barrier();
    check(
      (await count(automatic, 'pedidos_ayuda')) === 0,
      'Un permiso exacto tampoco concede el alcance de resumen.',
    );
    process.stdout.write('PASS 2.2: los permisos de resumen y exacta no se intercambian\n');

    phase = '2.3 reasignación operativa SQL';
    // The public API only reassigns cases in visto. This isolated database fixture exercises the
    // trigger/stream invariant with an exact row already present, without changing that decision.
    await db.transaction().execute(async (transaction) => {
      await sql`UPDATE emergencias.asignaciones SET finalizada_en=now() WHERE pedido_id=${caseId} AND rol='brigadista' AND finalizada_en IS NULL`.execute(
        transaction,
      );
      await sql`INSERT INTO emergencias.asignaciones(id,pedido_id,usuario_id,rol,asignada_en,acceso_hasta) VALUES (${newId()},${caseId},${second!.id},'brigadista',now(),${minutes(60)}::timestamptz)`.execute(
        transaction,
      );
    });
    await barrier();
    check(
      (await count(one, 'pedidos_ayuda')) === 0 && (await count(one, 'ubicaciones_casos')) === 0,
      'La reasignación debe retirar ambas filas del celular anterior.',
    );
    check(
      (await count(two, 'pedidos_ayuda')) === 0 && (await count(two, 'ubicaciones_casos')) === 0,
      'El celular nuevo debe abrir permisos propios.',
    );
    const summaryTwo = await open(second!, 'resumen');
    const exactTwo = await open(second!, 'exacta');
    await subscribe(two, 'caso_asignado', summaryTwo);
    await subscribe(two, 'caso_ubicacion_exacta', exactTwo);
    await barrier();
    check(
      (await count(two, 'pedidos_ayuda')) === 1 && (await count(two, 'ubicaciones_casos')) === 1,
      'El nuevo celular recibe ambas filas después de abrir.',
    );
    process.stdout.write(
      'PASS 2.3: reasignación SQL aislada retira ambas filas; nueva cuenta requiere apertura\n',
    );

    phase = '2.1 y 2.3 cierre';
    await call(`/pedidos-ayuda/${caseId}/estado`, await access(owner, []), {
      versionVista: await version(),
      estado: 'atendido',
    });
    await barrier();
    for (const client of [one, two, sameAccount])
      check(
        (await count(client, 'pedidos_ayuda')) === 0 &&
          (await count(client, 'ubicaciones_casos')) === 0,
        'Al cerrar ningún operador conserva resumen ni ubicación.',
      );
    check(
      (await count(author, 'ubicaciones_casos')) === 0,
      'El autor nunca recibe la ubicación operativa.',
    );
    process.stdout.write('PASS 2.1 y 2.3: salida de en camino y cierre retiran las filas\n');

    phase = '2.2 auditoría';
    const { rows: audit } = await sql<{
      usuario_id: string;
      pedido_id: string;
      ocurrido_en: Date;
      accion: string;
    }>`SELECT * FROM emergencias.auditoria WHERE pedido_id=${caseId} AND accion IN ('caso_abierto_en_celular','ubicacion_exacta_autorizada') ORDER BY id`.execute(
      db,
    );
    check(audit.length === 4, 'Cada apertura de alcance debe quedar auditada.');
    for (const account of [first!, second!]) {
      for (const action of ['caso_abierto_en_celular', 'ubicacion_exacta_autorizada']) {
        check(
          audit.filter((entry) => entry.usuario_id === account.id && entry.accion === action)
            .length === 1,
          'Cada actor debe tener exactamente una apertura de cada alcance.',
        );
      }
    }
    check(
      audit.every(
        (entry) =>
          entry.pedido_id === caseId &&
          [first!.id, second!.id].includes(entry.usuario_id) &&
          entry.ocurrido_en instanceof Date &&
          entry.ocurrido_en.getTime() >= startedAt &&
          entry.ocurrido_en.getTime() <= Date.now(),
      ),
      'La auditoría debe contener actor, fecha y caso.',
    );
    check(
      audit.every(
        (entry) =>
          Object.keys(entry).sort().join(',') === 'accion,id,ocurrido_en,pedido_id,rol,usuario_id',
      ),
      'La auditoría debe excluir el contenido.',
    );
    process.stdout.write(
      'PASS 2.2: cuatro aperturas auditadas con actor/fecha/caso, sin contenido\n',
    );
  } catch (error) {
    throw new Error(
      `Falló PowerSync en vivo en la fase «${phase}». ${error instanceof SafeFailure ? error.message : 'No se vuelcan datos de los clientes.'}`,
    );
  } finally {
    for (const subscription of subscriptions) subscription.unsubscribe();
    const cleanup = await Promise.allSettled([
      ...clients.map((client) => client.close()),
      ...(app ? [app.close()] : []),
      sql`UPDATE emergencias.eventos SET estado='normal',cerrado_en=now() WHERE id=${eventId}`.execute(
        db,
      ),
      sql`UPDATE emergencias.turnos SET finalizado_en=now() WHERE zona_id=${zoneId} AND finalizado_en IS NULL`.execute(
        db,
      ),
      sql`UPDATE identidad.usuarios SET eliminado_en=now() WHERE zona_id=${zoneId}`.execute(db),
    ]);
    const finalCleanup = await Promise.allSettled([
      db.destroy(),
      rm(directory, { recursive: true, force: true }),
    ]);
    check(
      [...cleanup, ...finalCleanup].every((result) => result.status === 'fulfilled'),
      'No terminó la limpieza del laboratorio.',
    );
  }
});
