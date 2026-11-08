# CI de la versión integrada de la Fase 2

Commit `4fc14c1` de `main` (integración de los cuatro lotes), el 8 de noviembre de 2026. Todos los
flujos de GitHub Actions terminaron en verde:

| Flujo | Run | Jobs |
|---|---|---|
| Backend | [42488254330](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42488254330) | Tipos, lint, fronteras, Sync Streams, pruebas y build · Integración con PostgreSQL 18 + PostGIS 3.6 · Humo k6 local y controles de umbrales |
| App | [42488254312](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42488254312) | Análisis, pruebas, formato y APK · Build de iOS (sin firma) |
| Consola | [42488254315](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42488254315) | Análisis, pruebas, formato y build web |
| Especificaciones | [42488254326](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42488254326) | OpenSpec |

Es la primera compilación de Android con los cambios nativos del Lote A (`FLAG_SECURE`,
`FlutterFragmentActivity` y biometría). La de iOS también se comprobó en una Mac local.

No cubre lo que necesita dispositivos o servicios reales: PowerSync en vivo, celulares, el
proveedor de SMS ni la consola contra la API desplegada. El humo k6 no certifica las 2.500
solicitudes por segundo.
