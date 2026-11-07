import { Controller, type ExecutionContext, Get, UnauthorizedException } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { BusinessRuleViolation } from '../domain/errors.js';
import type { Actor } from './actor.js';
import { AuthorizationGuard } from './authorization.guard.js';
import { Public, RequireRole, RequireTrustLevel } from './decorators.js';

@Controller('prueba')
class TestController {
  @Public()
  @RequireTrustLevel(3)
  @Get('publica')
  publicRoute(this: void): boolean {
    return true;
  }

  @Get('sin-restricciones')
  unrestricted(this: void): boolean {
    return true;
  }

  @RequireTrustLevel(1)
  @Get('nivel')
  trustProtected(this: void): boolean {
    return true;
  }

  @RequireRole('coordinador', 'brigadista')
  @Get('operativa')
  roleProtected(this: void): boolean {
    return true;
  }

  @RequireTrustLevel(2)
  @RequireRole('moderador')
  @Get('combinada')
  combined(this: void): boolean {
    return true;
  }
}

@RequireTrustLevel(3)
@RequireRole('administrador')
@Controller('clase')
class ClassProtectedController {
  @Get('restringida')
  restricted(this: void): boolean {
    return true;
  }

  @RequireTrustLevel(1)
  @RequireRole('coordinador')
  @Get('sobrescrita')
  overridden(this: void): boolean {
    return true;
  }
}

type ControllerType = typeof TestController | typeof ClassProtectedController;
type Handler = () => boolean;

function newActor(changes: Partial<Actor> = {}): Actor {
  return {
    id: '01970000-0000-7000-8000-0000000000a1',
    zoneId: '01970000-0000-7000-8000-000000000001',
    trustLevel: 2,
    roles: [],
    ...changes,
  };
}

describe('AuthorizationGuard', () => {
  const guard = new AuthorizationGuard(new Reflector());

  function activate(handler: Handler, actor?: Actor, controller: ControllerType = TestController) {
    const context = {
      getHandler: () => handler,
      getClass: () => controller,
      getType: () => 'http',
      switchToHttp: () => ({ getRequest: () => ({ actor }) }),
    } as unknown as ExecutionContext;
    return guard.canActivate(context);
  }

  it('permite rutas públicas y rutas sin metadata adicional', () => {
    expect(activate(TestController.prototype.publicRoute)).toBe(true);
    expect(activate(TestController.prototype.unrestricted)).toBe(true);
  });

  it('admite un nivel suficiente', () => {
    expect(activate(TestController.prototype.trustProtected, newActor({ trustLevel: 1 }))).toBe(
      true,
    );
  });

  it('rechaza un nivel insuficiente con el nivel actual y el requerido', () => {
    expect(() =>
      activate(TestController.prototype.trustProtected, newActor({ trustLevel: 0 })),
    ).toThrowError(
      expect.objectContaining({
        code: 'nivel_de_confianza_insuficiente',
        kind: 'forbidden',
        extensions: { nivelActual: 0, nivelRequerido: 1 },
      }),
    );
  });

  it.each(['coordinador', 'brigadista'] as const)(
    'admite cualquiera de los roles declarados: %s',
    (role) => {
      expect(activate(TestController.prototype.roleProtected, newActor({ roles: [role] }))).toBe(
        true,
      );
    },
  );

  it('rechaza un actor sin ninguno de los roles requeridos', () => {
    expect(() =>
      activate(TestController.prototype.roleProtected, newActor({ roles: ['moderador'] })),
    ).toThrowError(
      expect.objectContaining({
        code: 'rol_requerido',
        kind: 'forbidden',
        extensions: { rolesRequeridos: ['coordinador', 'brigadista'] },
      }),
    );
  });

  it('no concede otros roles implícitamente a administrador', () => {
    expect(() =>
      activate(TestController.prototype.roleProtected, newActor({ roles: ['administrador'] })),
    ).toThrowError(expect.objectContaining({ code: 'rol_requerido' }));
  });

  it('exige nivel y rol cuando ambos están declarados', () => {
    expect(
      activate(
        TestController.prototype.combined,
        newActor({ trustLevel: 2, roles: ['moderador'] }),
      ),
    ).toBe(true);
    expect(() =>
      activate(
        TestController.prototype.combined,
        newActor({ trustLevel: 1, roles: ['moderador'] }),
      ),
    ).toThrowError(expect.objectContaining({ code: 'nivel_de_confianza_insuficiente' }));
    expect(() =>
      activate(TestController.prototype.combined, newActor({ trustLevel: 2, roles: [] })),
    ).toThrowError(expect.objectContaining({ code: 'rol_requerido' }));
  });

  it('aplica metadata de clase y permite sobrescribirla en un método', () => {
    expect(() =>
      activate(
        ClassProtectedController.prototype.restricted,
        newActor({ trustLevel: 2, roles: ['administrador'] }),
        ClassProtectedController,
      ),
    ).toThrowError(expect.objectContaining({ code: 'nivel_de_confianza_insuficiente' }));
    expect(
      activate(
        ClassProtectedController.prototype.restricted,
        newActor({ trustLevel: 3, roles: ['administrador'] }),
        ClassProtectedController,
      ),
    ).toBe(true);
    expect(
      activate(
        ClassProtectedController.prototype.overridden,
        newActor({ trustLevel: 1, roles: ['coordinador'] }),
        ClassProtectedController,
      ),
    ).toBe(true);
  });

  it('no autoriza una ruta restringida sin actor autenticado', () => {
    expect(() => activate(TestController.prototype.trustProtected)).toThrow(UnauthorizedException);
  });

  it('usa BusinessRuleViolation para los rechazos de permisos', () => {
    expect(() => activate(TestController.prototype.roleProtected, newActor())).toThrow(
      BusinessRuleViolation,
    );
  });
});
