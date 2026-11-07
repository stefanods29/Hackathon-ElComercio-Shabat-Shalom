import { type Kysely, sql } from 'kysely';

/**
 * Demo data for development and tests. Ids are fixed so the app, the tests and the docs can
 * refer to the same neighbors. Names and districts are user-facing text (Spanish).
 */
export const PILOT_ZONE = {
  id: '01970000-0000-7000-8000-000000000001',
  name: 'Zona piloto (demo)',
  district: 'Lince (demo)',
  // Approximate rectangle in Lima; for demo only.
  boundaryWkt:
    'MULTIPOLYGON(((-77.045 -12.092, -77.025 -12.092, -77.025 -12.078, -77.045 -12.078, -77.045 -12.092)))',
} as const;

export const NEIGHBOR_ZONE = {
  id: '01970000-0000-7000-8000-000000000002',
  name: 'Zona vecina (demo)',
  district: 'Jesús María (demo)',
  boundaryWkt:
    'MULTIPOLYGON(((-77.060 -12.085, -77.045 -12.085, -77.045 -12.070, -77.060 -12.070, -77.060 -12.085)))',
} as const;

export const NEIGHBORS = {
  ana: {
    id: '01970000-0000-7000-8000-0000000000a1',
    phone: '+51900000001',
    name: 'Ana (vecina verificada)',
    trustLevel: 2,
    roles: [] as string[],
    zoneId: PILOT_ZONE.id,
  },
  beto: {
    id: '01970000-0000-7000-8000-0000000000b1',
    phone: '+51900000002',
    name: 'Beto (vecino)',
    trustLevel: 1,
    roles: [] as string[],
    zoneId: PILOT_ZONE.id,
  },
  carla: {
    id: '01970000-0000-7000-8000-0000000000c1',
    phone: '+51900000003',
    name: 'Carla (coordinadora)',
    trustLevel: 3,
    roles: ['coordinador'],
    zoneId: PILOT_ZONE.id,
  },
  dario: {
    id: '01970000-0000-7000-8000-0000000000d1',
    phone: '+51900000004',
    name: 'Darío (recién registrado)',
    trustLevel: 0,
    roles: [] as string[],
    zoneId: PILOT_ZONE.id,
  },
  elena: {
    id: '01970000-0000-7000-8000-0000000000e1',
    phone: '+51900000005',
    name: 'Elena (otra zona)',
    trustLevel: 2,
    roles: [] as string[],
    zoneId: NEIGHBOR_ZONE.id,
  },
} as const;

/** Inserts (or updates) the demo zones and neighbors. Idempotent. */
export async function seed(db: Kysely<unknown>): Promise<void> {
  for (const zone of [PILOT_ZONE, NEIGHBOR_ZONE]) {
    await sql`
      INSERT INTO identidad.zonas (id, nombre, distrito, limite)
      VALUES (${zone.id}, ${zone.name}, ${zone.district}, ST_GeogFromText(${zone.boundaryWkt}))
      ON CONFLICT (id) DO UPDATE
        SET nombre = EXCLUDED.nombre, distrito = EXCLUDED.distrito, limite = EXCLUDED.limite,
            actualizado_en = now()
    `.execute(db);
  }
  for (const neighbor of Object.values(NEIGHBORS)) {
    await sql`
      INSERT INTO identidad.usuarios (id, telefono, nombre_visible, zona_id, nivel_confianza, roles)
      VALUES (${neighbor.id}, ${neighbor.phone}, ${neighbor.name}, ${neighbor.zoneId},
              ${neighbor.trustLevel}, ${sql.val(neighbor.roles)}::text[])
      ON CONFLICT (id) DO UPDATE
        SET telefono = EXCLUDED.telefono, nombre_visible = EXCLUDED.nombre_visible,
            zona_id = EXCLUDED.zona_id, nivel_confianza = EXCLUDED.nivel_confianza,
            roles = EXCLUDED.roles, actualizado_en = now(), eliminado_en = NULL
    `.execute(db);
  }
}
