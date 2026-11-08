# Decisiones de arquitectura (ADR)

Correcciones y precisiones a la arquitectura aprobada (`docs/arquitectura/`), tomadas al construir
los cimientos de la Fase 0. Un ADR nuevo por decisión: `NNNN-titulo.md` con Contexto, Decisión y
Consecuencias.

| ADR | Decisión |
|---|---|
| [0001](0001-monorepo-y-contrato-primero.md) | Monorepo y contrato OpenAPI primero |
| [0002](0002-stack-del-backend.md) | Stack del backend: NestJS 12 ESM + Kysely |
| [0003](0003-autenticacion-es256-jwks.md) | Tokens ES256 con JWKS y audiencias separadas |
| [0004](0004-cifrado-local-powersync.md) | Cifrado local con `powersync` 2.x + SQLite3 Multiple Ciphers |
| [0005](0005-idempotencia-y-outbox-propios.md) | Idempotencia y outbox propios en PostgreSQL |
| [0006](0006-app-sin-generacion-de-codigo.md) | App sin generación de código y versiones fijadas |
| [0007](0007-convencion-de-nombres.md) | Código en inglés; contrato, datos y textos en español |
| [0008](0008-fuente-de-teselas.md) | PMTiles propio y salida XYZ para el mapa offline (Lote C) |
| [0009](0009-proveedor-de-codigos-firebase.md) | Firebase Authentication envía y comprueba los códigos por SMS (Lote B 1.4) |
| [0010](0010-precision-de-la-ubicacion-publica.md) | Copia pública de la ubicación redondeada a 3 decimales; exacta solo con consentimiento del proveedor (Fase 1, Lote A 1.1; propuesto) |

| [0014](0014-consola-web-en-flutter.md) | Consola web de operación en Flutter web, en un proyecto propio (Fase 2, Lote C 1; propuesto) |

La Fase 1 reserva el 0011 para la confirmación de residencia (Lote B, parte 4), y el 0012 y el 0013
para el proveedor de la nube y OpenTelemetry (Lote C, partes 4 y 5).
