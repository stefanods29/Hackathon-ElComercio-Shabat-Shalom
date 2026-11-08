import { describe, expect, it } from 'vitest';
import { reconcileFieldRequests } from './reconcile-field-requests.js';
import { newId } from '../src/shared/domain/ids.js';

describe('reconciliación de la prueba de campo', () => {
  const first = newId();
  const second = newId();
  const extra = newId();

  it('cuenta pedidos confirmados en varios celulares sin incluir sus intentos', () => {
    expect(
      reconcileFieldRequests(
        [first, second],
        [{ id: first }, { id: second }],
        [[{ recurso_id: first, estado: 'sent' }], [{ recurso_id: second, estado: 'sent' }]],
      ),
    ).toEqual({
      esperados: 2,
      filasEnColas: 2,
      filasEnServidor: 2,
      perdidos: 0,
      sinRegistroLocal: 0,
      duplicadosEnColas: 0,
      duplicadosEnServidor: 0,
      inesperadosEnColas: 0,
      inesperadosEnServidor: 0,
      sinAcuse: 0,
      rechazados: 0,
    });
  });

  it('detecta un pedido ausente de ambos orígenes, repeticiones, extras y falta de acuse', () => {
    expect(
      reconcileFieldRequests(
        [first, second],
        [{ id: first }, { id: first }, { id: extra }],
        [
          [{ recurso_id: first, estado: 'savedOnPhone' }],
          [
            { recurso_id: first, estado: 'sent' },
            { recurso_id: extra, estado: 'couldNotComplete' },
          ],
        ],
      ),
    ).toMatchObject({
      perdidos: 1,
      sinRegistroLocal: 1,
      duplicadosEnColas: 1,
      duplicadosEnServidor: 1,
      inesperadosEnColas: 1,
      inesperadosEnServidor: 1,
      sinAcuse: 1,
      rechazados: 1,
    });
  });

  it('rechaza un plan vacío o repetido, falta de colas y estados no reconocidos', () => {
    expect(() => reconcileFieldRequests([], [], [[]])).toThrow();
    expect(() => reconcileFieldRequests([first, first], [], [[]])).toThrow();
    expect(() => reconcileFieldRequests([first], [], [])).toThrow();
    expect(() =>
      reconcileFieldRequests([first], [], [[{ recurso_id: first, estado: 'desconocido' }]]),
    ).toThrow();
  });
});
