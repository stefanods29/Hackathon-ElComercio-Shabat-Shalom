# Módulo `reputacion`

**Responsabilidad:** Visto Bueno Vecinal, reseñas con fotos, ranking bayesiano y antifraude.

**Entidades principales:** Resena, FotoResena, VistoBueno.

**Cuándo y quién:** Fase 1 · el dueño se asigna al planificar la Fase 1.

## Estructura (igual en todos los módulos)

```text
reputacion/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── reputation.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`reputacion.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_reputacion_<descripcion>.ts`.
