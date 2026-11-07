# Módulo `directorio`

**Responsabilidad:** Oficios y profesiones cercanos: servicios, categorías y búsqueda por cercanía (PostGIS).

**Entidades principales:** PerfilProveedor, Servicio, Categoria.

**Cuándo y quién:** Fase 1 · el dueño se asigna al planificar la Fase 1.

## Estructura (igual en todos los módulos)

```text
directorio/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── directory.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`directorio.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_directorio_<descripcion>.ts`.
