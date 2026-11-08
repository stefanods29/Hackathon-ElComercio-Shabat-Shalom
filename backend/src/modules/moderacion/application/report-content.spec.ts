import { AccountAccess } from '../../../shared/auth/account-access.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import { newId } from '../../../shared/domain/ids.js';
import { ContentModerationRegistry } from '../../../shared/moderation/content-moderation.js';
import { InMemoryOutboxWriter } from '../../../shared/outbox/outbox.memory.js';
import type { ModerationCase, Report, ReportData } from '../domain/moderation.js';
import { ModerationEvents } from './moderation-events.js';
import type { ModerationStore } from './ports.js';
import { ReportContent } from './report-content.js';

const tx = {} as TransactionContext;
const unitOfWork: UnitOfWork = { run: (work) => work(tx) };
const now = new Date('2026-11-09T15:00:00Z');

function setup() {
  const id = newId();
  const ownerId = newId();
  const reporterId = newId();
  const content = { type: 'publicacion', id: newId() } as const;
  const data: ReportData = {
    id: newId(),
    content,
    reason: 'ofensivo',
    details: 'Texto del vecino',
  };
  const pending: ModerationCase = {
    id,
    content,
    ownerId,
    state: 'pendiente',
    reason: 'ofensivo',
    lastDecision: null,
    createdAt: now,
    updatedAt: now,
    firstReviewedAt: null,
    cursorDate: now.toISOString(),
  };
  const saved = new Map<string, Report>();
  const store = {
    lockContent: async () => {},
    lockReport: async () => {},
    findReport: async (_tx, id) => saved.get(id) ?? null,
    openCase: vi.fn(async () => pending),
    async saveReport(_tx, data, reporterId, caseId, createdAt) {
      const report = { ...data, reporterId, caseId, createdAt };
      saved.set(report.id, report);
      return report;
    },
  } satisfies Pick<
    ModerationStore,
    'lockContent' | 'lockReport' | 'findReport' | 'openCase' | 'saveReport'
  >;
  const registry = new ContentModerationRegistry();
  const read = vi.fn(async () => ({ ownerId, text: [], imageIds: [] }));
  registry.register('publicacion', { read, apply: async () => {} });
  const accounts = new AccountAccess();
  accounts.register({
    resolve: async (actor) => actor,
    lockActive: async () => true,
    lockStates: async () => new Map(),
  });
  const outbox = new InMemoryOutboxWriter();
  const port = store as unknown as ModerationStore;
  const useCase = new ReportContent(
    unitOfWork,
    { now: () => now },
    port,
    accounts,
    registry,
    new ModerationEvents(port, outbox),
  );
  return { useCase, data, reporterId, pending, store, outbox, saved, read };
}

describe('Registrar una denuncia', () => {
  it('abre un caso y registra un solo evento sin el detalle al repetir el identificador propio', async () => {
    const { useCase, data, reporterId, pending, store, outbox, saved } = setup();
    const result = await useCase.execute(reporterId, data);
    expect(result).toMatchObject({ created: true, report: { caseId: pending.id, createdAt: now } });
    await expect(useCase.execute(reporterId, data)).resolves.toEqual({ ...result, created: false });
    expect(saved.size).toBe(1);
    expect(store.openCase).toHaveBeenCalledTimes(1);
    expect(outbox.recorded).toEqual([
      expect.objectContaining({
        aggregateId: data.id,
        type: 'moderacion.denuncia_registrada',
        occurredAt: now,
        payload: {},
      }),
    ]);
  });

  it('distingue identificador ajeno o alterado de una repetición propia', async () => {
    const { useCase, data, reporterId } = setup();
    await useCase.execute(reporterId, data);
    await expect(useCase.execute(newId(), data)).rejects.toMatchObject({ code: 'id_en_uso' });
    await expect(useCase.execute(reporterId, { ...data, reason: 'spam' })).rejects.toMatchObject({
      code: 'id_en_uso',
    });
  });
});
