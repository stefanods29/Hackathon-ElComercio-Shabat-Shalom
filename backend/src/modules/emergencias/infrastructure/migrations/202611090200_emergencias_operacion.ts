import { type Kysely, sql } from 'kysely';

/** Extends A's original tables without changing request IDs or publishing private columns. */
export async function up(db: Kysely<unknown>): Promise<void> {
  await sql`
    CREATE TABLE emergencias.eventos (
      id uuid PRIMARY KEY, zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      nivel smallint NOT NULL CHECK (nivel BETWEEN 1 AND 3),
      estado text NOT NULL CHECK (estado IN ('emergencia','recuperacion','normal')),
      version int NOT NULL DEFAULT 1 CHECK (version > 0),
      activado_por uuid REFERENCES identidad.usuarios(id), activado_en timestamptz NOT NULL,
      cerrado_en timestamptz, fuente text NOT NULL, referencia_externa text, resumen jsonb, motivo_cierre text
    );
    CREATE UNIQUE INDEX eventos_zona_abierta_idx ON emergencias.eventos(zona_id)
      WHERE estado <> 'normal';
    CREATE TABLE emergencias.alertas_recibidas (
      referencia text PRIMARY KEY, procesada_en timestamptz NOT NULL
    );
    CREATE TABLE emergencias.habilitaciones (
      id uuid PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      rol text NOT NULL CHECK (rol IN ('coordinador','brigadista','curador')),
      dni_revisado_en timestamptz NOT NULL, capacitacion_en timestamptz NOT NULL,
      confidencialidad_en timestamptz NOT NULL, referencia_revision text NOT NULL,
      revisada_por uuid REFERENCES identidad.usuarios(id), vence_en timestamptz NOT NULL,
      revocada_en timestamptz, version int NOT NULL DEFAULT 1,
      UNIQUE (usuario_id,zona_id,rol), CHECK (char_length(referencia_revision) BETWEEN 1 AND 120)
    );
    CREATE INDEX habilitaciones_zona_idx ON emergencias.habilitaciones(zona_id,rol,vence_en)
      WHERE revocada_en IS NULL;
    CREATE TABLE emergencias.turnos (
      id uuid PRIMARY KEY, usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id),
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      rol text NOT NULL CHECK (rol IN ('coordinador','brigadista','curador')),
      inicio timestamptz NOT NULL, fin timestamptz NOT NULL, finalizado_en timestamptz,
      version int NOT NULL DEFAULT 1, CHECK (fin > inicio AND fin <= inicio + interval '24 hours')
    );
    CREATE INDEX turnos_zona_idx ON emergencias.turnos(zona_id,inicio,fin) WHERE finalizado_en IS NULL;
    CREATE TABLE emergencias.grupos_apoyo (
      id uuid PRIMARY KEY, zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      nombre text NOT NULL CHECK (char_length(nombre) BETWEEN 2 AND 100),
      verificado_en timestamptz NOT NULL, version int NOT NULL DEFAULT 1
    );
    CREATE TABLE emergencias.miembros_grupo (
      grupo_id uuid NOT NULL REFERENCES emergencias.grupos_apoyo(id),
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id), PRIMARY KEY (grupo_id,usuario_id)
    );
    CREATE TABLE emergencias.zonas_apoyo (
      zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      apoyo_zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      PRIMARY KEY(zona_id,apoyo_zona_id), CHECK(zona_id <> apoyo_zona_id)
    );
    ALTER TABLE emergencias.pedidos_ayuda
      ADD COLUMN evento_id uuid REFERENCES emergencias.eventos(id),
      ADD COLUMN zona_id uuid REFERENCES identidad.zonas(id),
      ADD COLUMN autor_id uuid REFERENCES identidad.usuarios(id),
      ADD COLUMN necesidad text NOT NULL DEFAULT 'otro' CHECK (necesidad IN ('agua','alimentos','medicamentos','traslado','albergue','otro')),
      ADD COLUMN prioridad text NOT NULL DEFAULT 'media' CHECK (prioridad IN ('alta','media','baja')),
      ADD COLUMN estado text NOT NULL DEFAULT 'enviado' CHECK (estado IN ('enviado','visto','en_camino','atendido','derivado','cerrado_sin_atender')),
      ADD COLUMN version int NOT NULL DEFAULT 1 CHECK (version > 0),
      ADD COLUMN celda text,
      ADD COLUMN visto_en timestamptz,
      ADD COLUMN escalar_en timestamptz,
      ADD COLUMN etapa_escalamiento int NOT NULL DEFAULT 0,
      ADD COLUMN huella text,
      ADD COLUMN anonimizado_en timestamptz;
    CREATE INDEX pedidos_cola_idx ON emergencias.pedidos_ayuda(zona_id,id) WHERE cerrado_en IS NULL;
    CREATE INDEX pedidos_autor_idx ON emergencias.pedidos_ayuda(autor_id,id);
    CREATE INDEX pedidos_plazo_idx ON emergencias.pedidos_ayuda(escalar_en) WHERE estado = 'enviado';
    CREATE INDEX pedidos_evento_cierre_idx ON emergencias.pedidos_ayuda(evento_id,id) WHERE anonimizado_en IS NULL;

    -- Neither private descriptions nor coordinates are part of the replication publication.
    CREATE TABLE emergencias.detalles_pedidos (
      pedido_id uuid PRIMARY KEY REFERENCES emergencias.pedidos_ayuda(id),
      descripcion text NOT NULL CHECK (char_length(descripcion) BETWEEN 1 AND 2000),
      lat double precision CHECK (lat BETWEEN -90 AND 90),
      lng double precision CHECK (lng BETWEEN -180 AND 180), CHECK ((lat IS NULL) = (lng IS NULL))
    );
    INSERT INTO emergencias.detalles_pedidos(pedido_id,descripcion)
      SELECT id,detalle FROM emergencias.pedidos_ayuda WHERE cerrado_en IS NULL;
    UPDATE emergencias.pedidos_ayuda SET detalle = 'Solicitud de apoyo vecinal';
    ALTER TABLE emergencias.asignaciones
      ADD COLUMN rol text NOT NULL DEFAULT 'brigadista' CHECK (rol IN ('coordinador','brigadista')),
      ADD COLUMN acceso_hasta timestamptz NOT NULL DEFAULT now();
    UPDATE emergencias.asignaciones a SET acceso_hasta = p.vence_en
      FROM emergencias.pedidos_ayuda p WHERE p.id = a.pedido_id;
    DROP INDEX emergencias.asignaciones_pedido_activo_idx;
    CREATE UNIQUE INDEX asignaciones_pedido_rol_activo_idx ON emergencias.asignaciones(pedido_id,rol)
      WHERE finalizada_en IS NULL;
    CREATE INDEX asignaciones_caducidad_idx ON emergencias.asignaciones(acceso_hasta) WHERE finalizada_en IS NULL;
    CREATE TABLE emergencias.historial_pedidos (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      pedido_id uuid NOT NULL REFERENCES emergencias.pedidos_ayuda(id),
      desde text, hasta text NOT NULL, usuario_id uuid REFERENCES identidad.usuarios(id),
      rol text NOT NULL, ocurrido_en timestamptz NOT NULL, motivo text CHECK (char_length(motivo) <= 500)
    );
    CREATE INDEX historial_pedido_idx ON emergencias.historial_pedidos(pedido_id,id);
    CREATE TABLE emergencias.escalamientos (
      pedido_id uuid NOT NULL REFERENCES emergencias.pedidos_ayuda(id), etapa int NOT NULL,
      usuario_id uuid REFERENCES identidad.usuarios(id), ocurrido_en timestamptz NOT NULL,
      PRIMARY KEY(pedido_id,etapa)
    );
    CREATE TABLE emergencias.auditoria (
      id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
      usuario_id uuid REFERENCES identidad.usuarios(id), pedido_id uuid REFERENCES emergencias.pedidos_ayuda(id),
      rol text NOT NULL, accion text NOT NULL CHECK (char_length(accion) <= 80), ocurrido_en timestamptz NOT NULL
    );
    CREATE INDEX auditoria_caso_idx ON emergencias.auditoria(pedido_id,id);
    CREATE TABLE emergencias.recursos_criticos (
      id uuid PRIMARY KEY, zona_id uuid NOT NULL REFERENCES identidad.zonas(id),
      reportante_id uuid REFERENCES identidad.usuarios(id), huella text NOT NULL,
      tipo text NOT NULL CHECK (tipo IN ('agua','alimentos','medicamentos','traslado','albergue','punto_encuentro')),
      cantidad int NOT NULL CHECK (cantidad BETWEEN 0 AND 1000000), celda text NOT NULL,
      reportado_en timestamptz NOT NULL, umbral_segundos int NOT NULL CHECK (umbral_segundos >= 60),
      verificacion text NOT NULL DEFAULT 'sin_verificar' CHECK (verificacion IN ('sin_verificar','confirmado','verificado')),
      confirmaciones int NOT NULL DEFAULT 0, etiqueta_publica text,
      fuente_url text, oficial boolean NOT NULL DEFAULT false, version int NOT NULL DEFAULT 1
    );
    CREATE INDEX recursos_zona_idx ON emergencias.recursos_criticos(zona_id,id);
    CREATE TABLE emergencias.confirmaciones_recursos (
      recurso_id uuid NOT NULL REFERENCES emergencias.recursos_criticos(id),
      usuario_id uuid NOT NULL REFERENCES identidad.usuarios(id), confirmado_en timestamptz NOT NULL,
      PRIMARY KEY(recurso_id,usuario_id)
    );
    CREATE TABLE emergencias.recursos_publicos (
      id uuid PRIMARY KEY REFERENCES emergencias.recursos_criticos(id), zona_id uuid NOT NULL,
      tipo text NOT NULL, cantidad int NOT NULL, celda text NOT NULL, reportado_en timestamptz NOT NULL,
      umbral_segundos int NOT NULL, verificacion text NOT NULL, confirmaciones int NOT NULL,
      etiqueta_publica text, fuente_url text, oficial boolean NOT NULL, version int NOT NULL
    );
    CREATE TABLE emergencias.agregados_celda (
      id text PRIMARY KEY, zona_id uuid NOT NULL REFERENCES identidad.zonas(id), celda text NOT NULL,
      necesidad text NOT NULL, cantidad int NOT NULL CHECK (cantidad >= 3), actualizado_en timestamptz NOT NULL
    );
    ALTER PUBLICATION powersync ADD TABLE emergencias.recursos_publicos, emergencias.agregados_celda;
    DO $block$ BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powersync_rol') THEN
        GRANT SELECT ON emergencias.recursos_publicos, emergencias.agregados_celda TO powersync_rol;
      END IF;
    END $block$;
  `.execute(db);
}

export async function down(): Promise<void> {
  throw new Error(
    'Esta migración contiene datos sensibles nuevos. Requiere un plan de reversión y retención revisado.',
  );
}
