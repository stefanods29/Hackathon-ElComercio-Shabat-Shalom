import { readFileSync } from 'node:fs';
import { z } from 'zod';

const requestId = z.uuidv7();
const plannedIds = z
  .array(requestId)
  .min(1)
  .refine((ids) => new Set(ids).size === ids.length);
const serverRows = z.array(z.strictObject({ id: requestId }));
const phoneRows = z.array(
  z.strictObject({
    recurso_id: requestId,
    estado: z.enum(['savedOnPhone', 'sent', 'couldNotComplete']),
  }),
);

function counts(ids: string[]): Map<string, number> {
  const result = new Map<string, number>();
  for (const id of ids) result.set(id, (result.get(id) ?? 0) + 1);
  return result;
}

/** The independent manifest keeps requests missing from both the phones and server measurable. */
export function reconcileFieldRequests(plan: unknown, server: unknown, phones: unknown[]) {
  const expected = new Set(plannedIds.parse(plan));
  const stored = counts(serverRows.parse(server).map((row) => row.id));
  const queued = z.array(phoneRows).min(1).parse(phones).flat();
  const byPhone = counts(queued.map((row) => row.recurso_id));
  const ids = [...expected];
  return {
    esperados: expected.size,
    filasEnColas: queued.length,
    filasEnServidor: [...stored.values()].reduce((total, count) => total + count, 0),
    perdidos: ids.filter((id) => !stored.has(id)).length,
    sinRegistroLocal: ids.filter((id) => !byPhone.has(id)).length,
    duplicadosEnColas: [...byPhone.values()].reduce((total, count) => total + count - 1, 0),
    duplicadosEnServidor: [...stored.values()].reduce((total, count) => total + count - 1, 0),
    inesperadosEnColas: queued.filter((row) => !expected.has(row.recurso_id)).length,
    inesperadosEnServidor: [...stored].reduce(
      (total, [id, count]) => (expected.has(id) ? total : total + count),
      0,
    ),
    sinAcuse: queued.filter((row) => row.estado === 'savedOnPhone').length,
    rechazados: queued.filter((row) => row.estado === 'couldNotComplete').length,
  };
}

if (import.meta.main) {
  const [plan, server, ...phones] = process.argv.slice(2);
  try {
    if (!plan || !server || !phones.length) throw new Error('Argumentos incompletos');
    const readJson = (file: string): unknown => JSON.parse(readFileSync(file, 'utf8'));
    const report = reconcileFieldRequests(readJson(plan), readJson(server), phones.map(readJson));
    console.log(JSON.stringify(report, null, 2));
    const { esperados: _plan, filasEnColas: _local, filasEnServidor: _server, ...issues } = report;
    process.exitCode = Object.values(issues).some((count) => count !== 0) ? 1 : 0;
  } catch {
    // Validation failures may include input values. Emit only a generic message.
    console.error(
      'Uso: tsx scripts/reconcile-field-requests.ts plan.json servidor.json celular.json [...]',
    );
    console.error(
      'Revisa los archivos: se requieren UUIDv7, un plan sin repetidos y estados válidos.',
    );
    process.exitCode = 2;
  }
}
