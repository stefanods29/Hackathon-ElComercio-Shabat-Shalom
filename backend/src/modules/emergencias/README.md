# Módulo `emergencias`

**Responsabilidad:** Eventos por zona, pedidos de ayuda con estados y escalamiento, recursos críticos, grupos de apoyo y turnos. Esquema restringido: datos sensibles.

**Entidades principales:** Evento, PedidoAyuda, Asignacion, RecursoCritico, GrupoApoyo, Turno.

**Cuándo y quién:** Fase 0: **Lote A** valida aquí los streams bajo demanda y la purga local con tablas mínimas. Fase 2: funcionalidad completa.

## Estructura (igual en todos los módulos)

```text
emergencias/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── emergencies.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`emergencias.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_emergencias_<descripcion>.ts`.
