# Encargo: pruebas de escalamiento y supresión del Lote B, y frescura de recursos en el tablero

Trabajas en el monorepo `Hackathon-ElComercio-Shabat-Shalom`. La Fase 2 ya está integrada en
`main` (commit `1fb5e12` o posterior) y toda su CI está en verde. Este encargo cierra dos pendientes
que no necesitan celulares. Antes de empezar, lee:

- `reglas-de-trabajo.md` y los `AGENTS.md` aplicables.
- `docs/fase-2/integracion.md`: qué se conectó entre lotes y qué se decidió. No reabras esas decisiones.
- `docs/fase-2/lote-b-modulo-emergencias/README.md` (partes 3 y 4) y su `entrega.md`.
- `docs/fase-2/lote-d-tablero-de-emergencia/README.md` (parte 3) y `integracion.md`.
- Los `tasks.md` de `openspec/changes/fase-2-lote-b-modulo-emergencias/`,
  `fase-2-lote-d-tablero-de-emergencia/` y `fase-2-lote-a-pedidos-offline-y-modo-operativo/`.

## Reglas de esta entrega

1. Dos ramas desde `main` actualizado, una por encargo:
   - `f2-lote-b/parte-3-4-pruebas`
   - `f2-lote-d/parte-3-frescura`
2. Commit y push **solo de tu rama**. Nada de merge, rebase, cherry-pick ni PR. No toques `main` ni
   borres ramas.
3. En responsables, autores o revisores solo van usuarios de GitHub del equipo: `JDiazD33`,
   `stefanods29`, `Defartion`, `KQuirosA`. Nunca el nombre de un agente, modelo o herramienta.
   Ninguna mención de herramientas de IA en commits, código ni documentos, y ninguna línea
   `Co-Authored-By`.
4. Marca una tarea `[x]` solo con evidencia: la prueba que la cubre pasando y el comando que corriste.
   Si algo no se puede probar, déjalo abierto y explica por qué.
5. No subas credenciales ni datos reales. Los datos de prueba son ficticios.
6. Si encuentras un error en el código de producción, arréglalo en el mismo commit que la prueba
   que lo demuestra, y explícalo en la entrega.

## Encargo 1 · Lote B: tiempos, reintentos, concurrencia y supresión

Rama `f2-lote-b/parte-3-4-pruebas`. Cierra B **3.3** y **4.3**.

Ya existe `backend/test/integration/emergencies.int-spec.ts`, que recorre el pedido de punta a punta
por la API. Úsalo de modelo: cómo crea cuentas nuevas con teléfonos propios (`+51977…`), habilita
coordinadores y brigadistas, abre turnos y activa el evento, y cómo limpia todo en `afterAll`
porque las suites comparten la base. Usa otro rango de teléfonos (por ejemplo `+51978…`) para no
chocar con esa suite ni con `otp.int-spec.ts`.

### 3.3 Escalamiento con reloj de prueba

Código: `backend/src/modules/emergencias/application/emergency-jobs.ts` (`escalate`, `warn`,
`maintain`, el trabajo `emergencias.escalar_pedido`) y `request.store.ts` (`due`,
`recordEscalation`, `wasEscalatedTo`). Los plazos salen de `EMERGENCY_REVIEW_HIGH_SECONDS`,
`_MEDIUM_` y `_LOW_` (`app-config.ts`).

Escribe una prueba de integración nueva, `backend/test/integration/emergency-escalation.int-spec.ts`,
que sustituya el proveedor `CLOCK` (`backend/src/shared/domain/clock.ts`) por un reloj controlado.
`createTestApp` acepta un tercer argumento `customize` para `overrideProvider`. Con
`JOB_QUEUE_DRIVER=memory` puedes llamar directamente a los métodos públicos de `EmergencyJobs`
(`escalate`, `maintain`). `warn` es privado: el aviso previo se prueba con el trabajo
`emergencias.avisar_plazo`, a través de la cola en memoria o del manejador que registra
`onModuleInit`.
Debe comprobar:

- Cada prioridad (alta, media y baja) escala cuando su plazo vence y no antes.
- Repetir el mismo trabajo de escalamiento (mismo pedido y misma etapa) no escala dos veces ni
  agrega una segunda fila a `emergencias.escalamientos`.
- El aviso previo sale un minuto antes del plazo y no sale si el pedido ya se vio.
- Al escalar, quien pidió ayuda recibe el aviso con `alternativas=directorio_emergencia`, sin datos
  sensibles en el texto (`notificaciones/domain/templates.ts`).
- No pasa de tres etapas.

### 4.3 Concurrencia y supresión

Código: `manage-resources.ts`, `resource.store.ts` (`confirm`, `refreshAggregates`, `aggregates`)
y `GET /v1/zonas/{zonaId}/celdas`.

En la misma rama, otra prueba de integración (`emergency-resources.int-spec.ts`) que compruebe:

- Dos actualizaciones del mismo recurso con la misma `versionVista` a la vez: una gana y la otra
  recibe 409 `conflicto_de_version`. Lánzalas con `Promise.all`.
- El mismo vecino confirma dos veces y el número de confirmaciones sube una sola vez.
- Dos pedidos en una celda y una necesidad no tienen fila en `agregados_celda` ni en la API; con tres
  aparece la fila con `cantidad: 3`. Ninguna respuesta trae totales por celda.
- Al cerrar o vencer pedidos, el agregado baja o desaparece en la siguiente instantánea.
- `recursos_publicos` nunca trae `reportante_id` ni `huella`.

Para estos casos crea los pedidos por la API. Los agregados se calculan con
`refreshAggregates`/`EMERGENCY_AGGREGATES_JOB`, así que llama al trabajo directamente.

### Verificación del Encargo 1

```bash
cd backend
npm run verify
DATABASE_URL_ADMIN='postgres://…' npm run test:integration
```

Marca B 3.3 y 4.3 solo si ambas pruebas pasan junto con toda la suite. No marques B 5.3, que pide
una revisión de migraciones del equipo.

## Encargo 2 · Lote D: frescura de los recursos con el límite del servidor

Rama `f2-lote-d/parte-3-frescura`. Cierra D **3.4** y la parte de reloj de A **4.2**. La de modo
avión de A 4.2 queda abierta.

### El problema que tienes que arreglar

Hoy hay dos criterios distintos de "posiblemente desactualizado":

- `public_emergency_board_page.dart` (A) usa el límite que manda el servidor por tipo de recurso
  (`umbral_segundos` del stream, configurado en B con `EMERGENCY_*_STALE_SECONDS`).
- `emergency_resource_pages.dart` (D) usa `resourceFreshnessPolicyProvider`, una tabla local con
  valores de ejemplo. La lee `CriticalResourceCard` (`isStale`).

En la cuenta real el tablero de D debe usar el límite del servidor. La práctica sigue con la tabla
local, porque no tiene servidor.

### Qué hacer

1. Agrega a `CriticalResource` (`app/lib/features/emergencias/domain/emergency.dart`) un campo
   opcional con el límite que llega del servidor, por ejemplo `Duration? staleAfter`.
2. En `OperationalEmergencyRepository._resource`
   (`app/lib/features/emergencias/data/operational_emergency_repository.dart`) llénalo con
   `PublicCriticalResource.staleAfter`.
3. Haz que `ResourceFreshnessPolicy.isStale` use `resource.staleAfter` cuando exista y la tabla
   local solo cuando no.
4. Pruebas en `app/test/features/emergencias/`:
   - De unidad, con reloj fijo, para cada tipo: justo antes del límite no está desactualizado y
     justo en el límite sí. Comprueba también el límite del servidor frente al local.
   - De widget de `CriticalResourceCard`: muestra "reportado hace X" y la marca de posiblemente
     desactualizado según el reloj (`clockProvider`). Muestra la fuente con su fecha de verificación
     solo si el recurso está verificado, y la insignia oficial solo si `official` es verdadero.
   - Del repositorio: un recurso del stream con `umbral_segundos` llega al tablero con ese límite.
     Sigue el patrón de `operational_emergency_repository_test.dart`, que escribe filas en
     `ps_data__…`.

### Verificación del Encargo 2

```bash
cd app
tool/verify.sh
```

Marca D 3.4 si pasan. En A 4.2 agrega una nota con lo verificado con reloj de prueba y déjala `[ ]`,
porque todavía falta el modo avión.

## Entrega

Para cada rama, devuélveme:

- Nombre de la rama y SHA final.
- Archivos cambiados y por qué. Si arreglaste un error de producción, cuál y cómo lo demuestra la
  prueba.
- Comandos corridos con su resultado (cantidad de pruebas que pasan).
- Tareas marcadas y las que quedan abiertas, con el motivo.
- Cualquier duda o desacuerdo con `docs/fase-2/integracion.md`, sin cambiarlo por tu cuenta.
