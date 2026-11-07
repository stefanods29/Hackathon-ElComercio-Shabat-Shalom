# Evidencia · Lote B · Parte 4 · Eventos y trabajos

- Fecha: 7 de noviembre de 2026.
- Responsable: JDiazD33.
- Entorno local: macOS 26.6.2, arm64; Node 26.13.0; PostgreSQL 18.6; PostGIS 3.7.
- Código de implementación: `b2419cbf49cb1c894fe8b455b4b9eb1cc840074b`.
- Rama: `lote-b/parte-4-trabajos`.
- Entrega: [PR #5](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/pull/5).

## Verificación local

| Comprobación | Resultado observado |
|---|---|
| `npm run verify` | Tipos, lint sin avisos, formato, fronteras, Sync Streams, pruebas y build correctos |
| Pruebas unitarias | 41 correctas en 8 archivos |
| `npm run test:integration` | 26 correctas en 4 archivos, contra PostgreSQL real |
| Prioridad | 1 crítico se procesó antes de los 1.000 normales pendientes |
| Relay concurrente | Dos relays publicaron 100 eventos cada uno: 200 ids distintos, sin duplicados |
| Fallo SQL después de enviar | El savepoint revirtió el trabajo; persistió el intento fallido y continuó el siguiente evento |
| Caída antes del commit | No quedó trabajo huérfano; el relay de reemplazo recuperó el evento pendiente |
| Reintentos | Tras 1 intento y 5 reintentos, el trabajo quedó fallido con el error conservado |
| Clave repetida | 10 solicitudes concurrentes generaron un solo trabajo pendiente |
| Demora | La fecha de inicio conservó los 60 segundos configurados |
| Limpieza | Borró claves vencidas y outbox antiguo publicado; conservó pendientes y registros recientes |
| Workers de Nest | Registró la limpieza a las 04:00 de `America/Lima` y publicó el evento de prueba |
| Cierre | El relay no solapó lotes y esperó el lote en curso antes de cerrar |
| OpenSpec estricto | 10 validaciones correctas, ninguna fallida |
| Redocly | Contrato válido; 2 advertencias preexistentes en salud y JWKS |
| Grafo y diff | Grafo regenerado y `git diff --check` sin errores |

Para reproducir la integración, apunta `DATABASE_URL_ADMIN` a una instancia PostgreSQL con
PostGIS y permisos para crear bases. La configuración de pruebas crea una base temporal,
aplica las migraciones, ejecuta los escenarios y elimina la base al terminar. Las pruebas de
pg-boss usan `colas_pruebas`; no necesitan PowerSync, Firebase ni credenciales externas.
La prueba de reintentos adelanta solo `start_after` de su fixture para evitar esperas largas;
las transiciones, el contador y el error son los reales de pg-boss.

## Humo del código compilado

Se ejecutaron `node dist/main.js` y `node dist/workers/main.js` simultáneamente contra una
base temporal vacía ya migrada, con claves de prueba generadas solo en memoria:

1. La API respondió 200 en `GET /v1/salud`.
2. El relay publicó el único evento de prueba, en un solo trabajo.
3. Se verificó el cron `0 4 * * *` con zona horaria `America/Lima`.
4. Ambos procesos cerraron con SIGTERM y se eliminó la base de humo.

## CI y revisión

CI usa PostgreSQL 18 + PostGIS 3.6, la combinación del proyecto; el entorno local tiene PostGIS
3.7. Los resultados de CI se agregan al cerrar la tarea 4.4. La aprobación e integración
corresponden al Lote A; esta evidencia no sustituye esa revisión.
