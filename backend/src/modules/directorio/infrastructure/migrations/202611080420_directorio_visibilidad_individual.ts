import { type Kysely, sql } from 'kysely';

export async function up(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    ALTER TABLE directorio.servicios ADD COLUMN oculto_individual_en timestamptz;
    UPDATE directorio.servicios SET oculto_individual_en = oculto_en WHERE oculto_en IS NOT NULL;
    UPDATE directorio.servicios AS servicio SET oculto_en = proveedor.oculto_en
    FROM directorio.proveedores AS proveedor
    WHERE servicio.proveedor_id = proveedor.id AND servicio.oculto_en IS NULL AND proveedor.oculto_en IS NOT NULL;
  `,
    )
    .execute(db);
}

export async function down(db: Kysely<unknown>): Promise<void> {
  await sql
    .raw(
      `
    UPDATE directorio.servicios SET oculto_en = oculto_individual_en;
    ALTER TABLE directorio.servicios DROP COLUMN oculto_individual_en;
  `,
    )
    .execute(db);
}
