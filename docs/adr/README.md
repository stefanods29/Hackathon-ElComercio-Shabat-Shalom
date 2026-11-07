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
