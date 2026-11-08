import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    -- Phase 2, Lot C: urgent notices to coordinators and brigade members with SMS backup.
    CREATE TABLE notificaciones.avisos_urgentes (
      aviso_id uuid PRIMARY KEY,
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      plantilla text NOT NULL
        CHECK (plantilla IN ('caso_asignado', 'pedido_por_escalar', 'pedido_escalado')),
      caso_id uuid,
      huella text NOT NULL,
      estado text NOT NULL DEFAULT 'esperando_confirmacion' CHECK (estado IN (
        'esperando_confirmacion', 'confirmado', 'sms_enviando', 'sms_enviado', 'sin_respaldo'
      )),
      motivo text CHECK (motivo IN ('tope_de_gasto', 'sin_proveedor', 'sin_telefono', 'sms_fallido')),
      dispositivos_alcanzados smallint NOT NULL DEFAULT 0 CHECK (dispositivos_alcanzados >= 0),
      creado_en timestamptz NOT NULL DEFAULT now(),
      confirmar_antes_de timestamptz NOT NULL,
      confirmado_en timestamptz,
      sms_enviado_en timestamptz,
      sms_intentos smallint NOT NULL DEFAULT 0 CHECK (sms_intentos >= 0),
      costo_centavos integer NOT NULL DEFAULT 0 CHECK (costo_centavos >= 0),
      CHECK ((estado = 'sin_respaldo') = (motivo IS NOT NULL))
    );
    CREATE INDEX avisos_urgentes_pendientes_idx
      ON notificaciones.avisos_urgentes (usuario_id, creado_en DESC)
      WHERE confirmado_en IS NULL;
    CREATE INDEX avisos_urgentes_creado_idx ON notificaciones.avisos_urgentes (creado_en);

    -- Daily SMS spending in America/Lima days; the monthly cap is the sum of the month's rows.
    CREATE TABLE notificaciones.gasto_sms (
      dia date PRIMARY KEY,
      centavos integer NOT NULL DEFAULT 0 CHECK (centavos >= 0),
      mensajes integer NOT NULL DEFAULT 0 CHECK (mensajes >= 0)
    );
    -- Deliberately excluded from the PowerSync publication: phones and costs stay on the server.
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    DROP TABLE notificaciones.gasto_sms;
    DROP TABLE notificaciones.avisos_urgentes;
  `,
    )
    .execute(db);
}
