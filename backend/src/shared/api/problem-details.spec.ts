import { NotFoundException, UnauthorizedException } from '@nestjs/common';
import {
  BusinessRuleViolation,
  ResourceNotFound,
  ValidationError,
  VersionConflict,
} from '../domain/errors.js';
import { isDefinitiveRejection, problemType, toProblemDetails } from './problem-details.js';

describe('toProblemDetails (RFC 9457)', () => {
  it('traduce cada error del dominio a su código HTTP con un código estable', () => {
    const cases: Array<[unknown, number, string]> = [
      [new ValidationError([{ field: 'titulo', message: 'muy corto' }]), 400, 'validacion'],
      [new ResourceNotFound('la publicación', 'x'), 404, 'recurso_no_encontrado'],
      [new VersionConflict(1, 2), 409, 'conflicto_de_version'],
      [
        new BusinessRuleViolation('favor_no_disponible', 'ya tomado', 'conflict'),
        409,
        'favor_no_disponible',
      ],
      [new BusinessRuleViolation('nivel', 'no', 'forbidden'), 403, 'nivel'],
      [new BusinessRuleViolation('titulo_invalido', 'no'), 422, 'titulo_invalido'],
      [new UnauthorizedException('sin token'), 401, 'no_autenticado'],
      [new NotFoundException(), 404, 'recurso_no_encontrado'],
    ];
    for (const [error, status, code] of cases) {
      const problem = toProblemDetails(error, '/v1/x');
      expect(problem).toMatchObject({
        status,
        codigo: code,
        type: problemType(code),
        instance: '/v1/x',
      });
      expect(problem.title).toBeTruthy();
    }
  });

  it('incluye los campos inválidos y las versiones en conflicto', () => {
    expect(
      toProblemDetails(new ValidationError([{ field: 'id', message: 'no es UUIDv7' }])),
    ).toMatchObject({
      errores: [{ campo: 'id', mensaje: 'no es UUIDv7' }],
    });
    expect(toProblemDetails(new VersionConflict(1, 3))).toMatchObject({
      versionEsperada: 1,
      versionActual: 3,
    });
  });

  it('nunca filtra detalles internos de errores inesperados', () => {
    const problem = toProblemDetails(new Error('password=secreto en la cadena de conexión'));
    expect(problem.status).toBe(500);
    expect(problem.codigo).toBe('error_interno');
    expect(JSON.stringify(problem)).not.toContain('secreto');
  });

  it('clasifica qué rechazos son definitivos para la cola del celular', () => {
    expect([400, 401, 403, 404, 409, 422].every(isDefinitiveRejection)).toBe(true);
    expect([408, 429, 500, 502, 503].some(isDefinitiveRejection)).toBe(false);
  });
});
