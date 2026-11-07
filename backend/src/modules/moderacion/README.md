# Módulo `moderacion`

**Responsabilidad:** Denuncias, cola de revisión y sanciones (cadena: texto → imagen → reputación del autor → revisión humana).

**Entidades principales:** Denuncia, Caso.

**Cuándo y quién:** Fase 1 · el dueño se asigna al planificar la Fase 1.

## Estructura (igual en todos los módulos)

```text
moderacion/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── moderation.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`moderacion.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_moderacion_<descripcion>.ts`.
