import { testConfig } from '../../../../test/support/config.js';
import { TokenService } from '../../../shared/auth/token.service.js';
import type { TransactionContext, UnitOfWork } from '../../../shared/db/unit-of-work.js';
import type { Clock } from '../../../shared/domain/clock.js';
import { newId } from '../../../shared/domain/ids.js';
import { InMemorySessionRepository } from '../infrastructure/session.repository.memory.js';
import { CreateSession, hashRefreshToken, type IssuedRefreshSession } from './create-session.js';
import type { RegisteredUser, UserRepository } from './ports.js';
import { RefreshSession } from './refresh-session.js';

describe('RefreshSession', () => {
  const transaction = {} as TransactionContext;
  const config = testConfig();
  let now: Date;
  let sessions: InMemorySessionRepository;
  let tokens: TokenService;
  let refresh: RefreshSession;
  let original: IssuedRefreshSession;
  let user: RegisteredUser | null;
  let commits: number;

  beforeEach(async () => {
    now = new Date('2026-11-07T15:00:00Z');
    const clock: Clock = { now: () => now };
    sessions = new InMemorySessionRepository();
    tokens = new TokenService(config, clock);
    commits = 0;
    // Roll back the memory snapshot on failure, just as the real UnitOfWork does.
    const unitOfWork: UnitOfWork = {
      async run(work) {
        const snapshot = structuredClone(sessions.records);
        try {
          const result = await work(transaction);
          commits += 1;
          return result;
        } catch (error) {
          sessions.records.clear();
          for (const [id, record] of snapshot) sessions.records.set(id, record);
          throw error;
        }
      },
    };
    user = {
      id: newId(),
      phone: '+51914000000',
      displayName: 'Vecino',
      zoneId: null,
      trustLevel: 0,
      roles: [],
    };
    const users: UserRepository = {
      findById: async () => user,
      findByPhone: async () => user,
      findOrCreateByPhone: async () => {
        throw new Error('No debe registrar al renovar');
      },
    };
    const create = new CreateSession(sessions, tokens, config, clock, users);
    refresh = new RefreshSession(unitOfWork, sessions, users, create, config, clock);
    original = await create.inTransaction(transaction, user, 'dispositivo de prueba');
  });

  afterEach(() => vi.restoreAllMocks());

  it('rota el secreto opaco, conserva familia y dispositivo, y guarda solo HMAC', async () => {
    now = new Date('2026-11-08T15:00:00Z');
    const next = await refresh.execute(original.refreshToken);
    expect(next.refreshToken).toMatch(/^[A-Za-z0-9_-]{43}$/);
    expect(next.refreshToken).not.toBe(original.refreshToken);
    expect(next.refreshExpiresAt.toISOString()).toBe('2026-12-08T15:00:00.000Z');
    const before = await tokens.verifyAccess(original.accessToken).catch(() => null);
    expect(before).toBeNull(); // Access expired; refresh does not depend on it.
    const records = [...sessions.records.values()];
    expect(records).toHaveLength(2);
    expect(records[0]?.rotatedAt).toEqual(now);
    expect(records[1]).toMatchObject({
      familyId: records[0]?.familyId,
      device: 'dispositivo de prueba',
      rotatedAt: null,
    });
    expect(records[1]?.refreshHash).toBe(
      hashRefreshToken(next.refreshToken, config.REFRESH_TOKEN_SECRET),
    );
    expect(JSON.stringify(records)).not.toContain(next.refreshToken);
    await expect(tokens.verifyAccess(next.accessToken)).resolves.toMatchObject({
      sessionId: records[0]?.familyId,
    });
  });

  it('relee zona, nivel y roles antes de emitir los tokens nuevos', async () => {
    user = { ...original.user, zoneId: newId(), trustLevel: 3, roles: ['moderador'] };
    const next = await refresh.execute(original.refreshToken);
    await expect(tokens.verifyAccess(next.accessToken)).resolves.toMatchObject({
      zoneId: user.zoneId,
      trustLevel: 3,
      roles: ['moderador'],
    });
    expect(next.user).toEqual(user);
  });

  it('persiste la revocación de toda la familia antes de lanzar el error de reutilización', async () => {
    const next = await refresh.execute(original.refreshToken);
    await expect(refresh.execute(original.refreshToken)).rejects.toMatchObject({
      code: 'sesion_revocada',
    });
    expect(commits).toBe(2);
    expect(
      [...sessions.records.values()].every(
        (record) => record.revokedAt && record.reason === 'reutilizacion',
      ),
    ).toBe(true);
    await expect(refresh.execute(next.refreshToken)).rejects.toMatchObject({
      code: 'sesion_revocada',
    });
  });

  it('rechaza un token desconocido sin crear filas', async () => {
    await expect(refresh.execute('desconocido')).rejects.toMatchObject({ code: 'sesion_invalida' });
    expect(sessions.records.size).toBe(1);
  });

  it('rechaza al alcanzar exactamente la fecha de vencimiento', async () => {
    now = original.refreshExpiresAt;
    await expect(refresh.execute(original.refreshToken)).rejects.toMatchObject({
      code: 'sesion_invalida',
    });
    expect([...sessions.records.values()][0]?.rotatedAt).toBeNull();
  });

  it('rechaza una familia revocada aunque el refresh no se haya consumido', async () => {
    const record = [...sessions.records.values()][0]!;
    await sessions.revokeFamily(transaction, record.userId, record.familyId, now, 'cierre');
    await expect(refresh.execute(original.refreshToken)).rejects.toMatchObject({
      code: 'sesion_revocada',
    });
    expect(sessions.records.size).toBe(1);
  });

  it('revoca y no emite tokens si la cuenta dejó de estar disponible', async () => {
    user = null;
    await expect(refresh.execute(original.refreshToken)).rejects.toMatchObject({
      code: 'sesion_revocada',
    });
    expect(commits).toBe(1);
    expect([...sessions.records.values()][0]?.revokedAt).toEqual(now);
  });

  it('revierte la rotación completa si falla la firma y permite usar el refresh original', async () => {
    vi.spyOn(tokens, 'issueAccess').mockRejectedValueOnce(new Error('fallo de firma'));
    await expect(refresh.execute(original.refreshToken)).rejects.toThrow('fallo de firma');
    expect(commits).toBe(0);
    expect(sessions.records.size).toBe(1);
    expect([...sessions.records.values()][0]?.rotatedAt).toBeNull();
    await expect(refresh.execute(original.refreshToken)).resolves.toHaveProperty('refreshToken');
  });
});
