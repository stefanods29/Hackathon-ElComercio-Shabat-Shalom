import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    ALTER TABLE moderacion.casos
      ADD COLUMN autor_id uuid REFERENCES identidad.usuarios(id),
      ADD COLUMN ultima_accion text CHECK (ultima_accion IN ('publicar', 'ocultar', 'restaurar', 'descartar', 'sancionar')),
      ADD CONSTRAINT casos_estado_chk CHECK (estado IN ('pendiente', 'resuelto')),
      ADD CONSTRAINT casos_tipo_chk CHECK (tipo_contenido IN ('publicacion', 'resena', 'servicio', 'foto', 'proveedor'));
    CREATE INDEX casos_creado_en_idx ON moderacion.casos (creado_en);
    CREATE INDEX casos_autor_idx ON moderacion.casos (autor_id);

    CREATE TABLE moderacion.denuncias (
      id uuid PRIMARY KEY CHECK (substring(id::text FROM 15 FOR 1) = '7'),
      caso_id uuid NOT NULL REFERENCES moderacion.casos(id),
      denunciante_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      motivo text NOT NULL CHECK (motivo IN ('spam', 'ofensivo', 'informacion_falsa', 'datos_personales', 'peligroso', 'otro')),
      detalle text CHECK (char_length(detalle) <= 500),
      senal text,
      creada_en timestamptz NOT NULL
    );
    CREATE INDEX denuncias_caso_idx ON moderacion.denuncias (caso_id);
    CREATE INDEX denuncias_denunciante_idx ON moderacion.denuncias (denunciante_id);

    CREATE TABLE moderacion.decisiones (
      id uuid PRIMARY KEY DEFAULT uuidv7(),
      caso_id uuid NOT NULL REFERENCES moderacion.casos(id),
      moderador_id uuid REFERENCES identidad.usuarios(id),
      accion text NOT NULL CHECK (accion IN ('publicar', 'ocultar', 'restaurar', 'descartar', 'sancionar')),
      motivo text NOT NULL CHECK (char_length(motivo) BETWEEN 1 AND 500),
      decidida_en timestamptz NOT NULL
    );
    CREATE INDEX decisiones_caso_idx ON moderacion.decisiones (caso_id, decidida_en, id);
    CREATE INDEX decisiones_moderador_idx ON moderacion.decisiones (moderador_id);

    CREATE TABLE moderacion.sanciones (
      id uuid PRIMARY KEY DEFAULT uuidv7(),
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      decision_id uuid NOT NULL UNIQUE REFERENCES moderacion.decisiones(id),
      desde timestamptz NOT NULL,
      hasta timestamptz NOT NULL CHECK (hasta > desde)
    );
    CREATE INDEX sanciones_usuario_hasta_idx ON moderacion.sanciones (usuario_id, hasta);

    CREATE TABLE moderacion.visibilidad (
      tipo_contenido text NOT NULL CHECK (tipo_contenido IN ('publicacion', 'resena', 'servicio', 'foto', 'proveedor')),
      contenido_id uuid NOT NULL,
      evento text NOT NULL CHECK (evento IN ('moderacion.contenido_aprobado', 'moderacion.contenido_ocultado', 'moderacion.contenido_restaurado')),
      ocurrido_en timestamptz NOT NULL,
      aplicado_en timestamptz,
      PRIMARY KEY (tipo_contenido, contenido_id)
    );
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    DROP TABLE moderacion.visibilidad;
    DROP TABLE moderacion.sanciones;
    DROP TABLE moderacion.decisiones;
    DROP TABLE moderacion.denuncias;
    DROP INDEX moderacion.casos_creado_en_idx;
    DROP INDEX moderacion.casos_autor_idx;
    ALTER TABLE moderacion.casos
      DROP CONSTRAINT casos_tipo_chk,
      DROP CONSTRAINT casos_estado_chk,
      DROP COLUMN ultima_accion,
      DROP COLUMN autor_id;
  `,
    )
    .execute(db);
}
