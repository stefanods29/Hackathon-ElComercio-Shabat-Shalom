import { type Kysely, sql } from 'kysely';

/**
 * Contadores de sincronización que cada celular envía como máximo una vez al día (Fase 1, Lote A,
 * parte 3). La tabla no tiene columnas de vecino ni de dispositivo, guarda solo el día de
 * recepción y usa ids aleatorios (no UUIDv7, que llevan la hora), así que una fila no se puede
 * cruzar con una sesión ni con una solicitud. No se publica en PowerSync.
 */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
CREATE TABLE compartido.telemetria_sincronizacion (
  id                                   uuid    PRIMARY KEY DEFAULT gen_random_uuid(),
  recibido_el                          date    NOT NULL,
  version_app                          text    NOT NULL CHECK (version_app ~ '^[0-9A-Za-z.+-]{1,32}$'),
  sistema                              text    NOT NULL CHECK (sistema IN ('android', 'ios')),
  duracion_periodo_minutos             integer NOT NULL CHECK (duracion_periodo_minutos >= 0),
  cola_pendientes                      integer NOT NULL CHECK (cola_pendientes >= 0),
  envios_confirmados                   integer NOT NULL CHECK (envios_confirmados >= 0),
  tiempo_hasta_enviado_p50_segundos    integer CHECK (tiempo_hasta_enviado_p50_segundos >= 0),
  tiempo_hasta_enviado_p95_segundos    integer CHECK (tiempo_hasta_enviado_p95_segundos >= 0),
  rechazos_permanentes                 jsonb   NOT NULL DEFAULT '{}'::jsonb
                                       CHECK (jsonb_typeof(rechazos_permanentes) = 'object'),
  segundos_desde_ultima_sincronizacion integer CHECK (segundos_desde_ultima_sincronizacion >= 0),
  errores_de_conexion                  integer NOT NULL CHECK (errores_de_conexion >= 0)
);
CREATE INDEX telemetria_sincronizacion_recibido_idx
  ON compartido.telemetria_sincronizacion (recibido_el);
`,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql.raw(`DROP TABLE IF EXISTS compartido.telemetria_sincronizacion;`).execute(db);
}
