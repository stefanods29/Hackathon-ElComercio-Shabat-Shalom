# Módulo `notificaciones`

**Responsabilidad:** Avisos por tópico de zona (solo públicos) y por token de dispositivo (sin datos sensibles en el texto).

**Entidades principales:** Dispositivo, Suscripcion, Plantilla.

**Cuándo y quién:** Fase 0: **Lote C**.

## Estructura (igual en todos los módulos)

```text
notificaciones/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── notifications.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`notificaciones.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_notificaciones_<descripcion>.ts`.
