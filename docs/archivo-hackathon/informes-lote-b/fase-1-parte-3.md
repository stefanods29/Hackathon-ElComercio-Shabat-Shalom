# Informe de entrega · Fase 1, Lote B, Parte 3

Fecha local: 7 de noviembre de 2026 (America/Lima). Responsable: JDiazD33.
Estado: **Lista para revisión**. Implementación escrita, comprobaciones a cargo del supervisor.

## 1. Rama, base y SHA final

- Rama: `f1-lote-b/parte-3-resenas`.
- Base: `f1-lote-b/parte-2-busqueda` → `87535d7d234c177c55957665951ea34f95433aff`.
- SHA final local: `d7973dd4dc5c7ee64d654762f037db34862399c9`.
- SHA remoto: `d7973dd4dc5c7ee64d654762f037db34862399c9`, confirmado con `git ls-remote` después del push.
- Worktree: `/Users/joaquindiaz05/Documents/hackaton comercio/Hackathon-ElComercio-Shabat-Shalom-f1-lote-b-parte-3`. Árbol limpio al terminar.

## 2. Historial y tamaño del cambio

`git log --oneline 87535d7d234c177c55957665951ea34f95433aff..HEAD`:

```text
d7973dd Documenta la entrega de reseñas y ranking para revisión
26e5dba Detecta patrones de reseñas y abre casos de revisión
1de5714 Implementa reseñas, Visto Bueno y recálculo desde los hechos
f25901a Expón datos mínimos y proyecta el ranking bayesiano
c5b716d Crea las tablas de reputación y casos de antifraude
16f0898 Define el contrato de reseñas y Visto Bueno
```

`git diff --stat 87535d7d234c177c55957665951ea34f95433aff..HEAD`:

```text
backend/.env.example                               |   4 +
 backend/src/modules/directorio/README.md           |  11 +-
 .../reputation-aggregates-handler.spec.ts          |  78 ++++
 .../application/reputation-aggregates-handler.ts   |  78 ++++
 .../directorio/application/reputation-ports.ts     |  56 +++
 backend/src/modules/directorio/directory.module.ts |  10 +
 .../directorio/domain/reputation-ranking.spec.ts   |  18 +
 .../directorio/domain/reputation-ranking.ts        |  13 +
 backend/src/modules/directorio/index.ts            |   5 +
 .../202611080210_directorio_control_recalculo.ts   |  19 +
 .../infrastructure/reputation.store.kysely.ts      | 121 +++++
 .../identidad/application/reviewer-reader.ts       |  17 +
 backend/src/modules/identidad/identity.module.ts   |   4 +
 backend/src/modules/identidad/index.ts             |   5 +
 .../infrastructure/reviewer.reader.kysely.ts       |  39 ++
 backend/src/modules/moderacion/README.md           |  12 +
 .../src/modules/moderacion/application/ports.ts    |  11 +
 .../application/review-pattern-handler.spec.ts     |  30 ++
 .../application/review-pattern-handler.ts          |  39 ++
 .../modules/moderacion/domain/review-pattern.ts    |   5 +
 .../migrations/202611080220_moderacion_casos.ts    |  27 ++
 .../infrastructure/review-case.store.kysely.ts     |  20 +
 .../src/modules/moderacion/moderation.module.ts    |  16 +-
 backend/src/modules/reputacion/README.md           |  49 +-
 .../reputacion/api/reputation.controller.ts        |  68 +++
 backend/src/modules/reputacion/api/schemas.ts      |  41 ++
 .../modules/reputacion/application/endorsements.ts |  60 +++
 .../src/modules/reputacion/application/ports.ts    |  79 ++++
 .../application/recalculate-reputation.ts          |  58 +++
 .../reputacion/application/reputation-access.ts    |  47 ++
 .../reputacion/application/reputation-events.ts    |  14 +
 .../application/reputation-workflows.spec.ts       | 260 +++++++++++
 .../modules/reputacion/application/write-review.ts | 149 ++++++
 .../src/modules/reputacion/domain/endorsement.ts   |  17 +
 .../src/modules/reputacion/domain/review-policy.ts |  28 ++
 .../src/modules/reputacion/domain/review.spec.ts   |  62 +++
 backend/src/modules/reputacion/domain/review.ts    |  94 ++++
 backend/src/modules/reputacion/index.ts            |   7 +
 .../migrations/202611080200_reputacion_base.ts     |  90 ++++
 .../infrastructure/reputation.repository.kysely.ts | 243 ++++++++++
 .../infrastructure/reputation.repository.memory.ts | 123 +++++
 .../infrastructure/review-photo.reader.memory.ts   |  22 +
 .../modules/reputacion/infrastructure/tables.ts    |  49 ++
 .../src/modules/reputacion/reputation.module.ts    |  35 +-
 backend/src/shared/config/app-config.ts            |   2 +
 backend/src/workers/workers.module.ts              |   4 +
 .../integration/directory-migrations.int-spec.ts   |  12 +
 backend/test/integration/migrations.int-spec.ts    |   7 +-
 .../integration/reputation-migrations.int-spec.ts  |  88 ++++
 backend/test/integration/reputation.int-spec.ts    | 510 +++++++++++++++++++++
 contracts/openapi.yaml                             | 167 +++++++
 .../README.md                                      |   4 +-
 .../parte-3.md                                     | 145 ++++++
 53 files changed, 3143 insertions(+), 29 deletions(-)
```

## 3. Tareas escritas

### Archivos por tarea

Las rutas son relativas a la raíz. Las de los módulos abreviados comienzan en `backend/src/modules/`.

| Tarea | Código escrito | Pruebas escritas |
|---|---|---|
| 3.1 | `contracts/openapi.yaml` en el primer commit `16f0898`; `reputacion/api/schemas.ts`, `api/reputation.controller.ts` | `backend/test/integration/reputation.int-spec.ts`: contrato, 201/200, 400/401/403/404/409/422/429, reintentos; Redocly pendiente |
| 3.2 | `reputacion/infrastructure/migrations/202611080200_reputacion_base.ts`, `infrastructure/tables.ts` | `backend/test/integration/reputation-migrations.int-spec.ts`, más `migrations.int-spec.ts` y `directory-migrations.int-spec.ts` ajustadas para publicación y reversión en orden |
| 3.3 | `reputacion/domain/review.ts`, `domain/review-policy.ts`, `application/write-review.ts`, `application/reputation-access.ts`, `application/ports.ts`, adaptadores `reputation.repository.kysely.ts`, `reputation.repository.memory.ts`, `review-photo.reader.memory.ts`; lectores públicos de Directorio e Identidad | `reputacion/domain/review.spec.ts`, `application/reputation-workflows.spec.ts` y `reputation.int-spec.ts`: autor/servicio, estado, cuota, fotos, outbox y rollback |
| 3.4 | `reputacion/domain/endorsement.ts`, `application/endorsements.ts`, `application/reputation-events.ts` y repositorios | `reputation-workflows.spec.ts` y `reputation.int-spec.ts`: nivel al otorgar, id persistente, bajas, cola y ranking |
| 3.5 | `reputacion/application/recalculate-reputation.ts`, `directorio/application/reputation-aggregates-handler.ts`, `application/reputation-ports.ts`, `domain/reputation-ranking.ts`, `infrastructure/reputation.store.kysely.ts`, `202611080210_directorio_control_recalculo.ts`, `backend/src/workers/workers.module.ts` | `reputation-workflows.spec.ts`, `directorio/domain/reputation-ranking.spec.ts`, `directorio/application/reputation-aggregates-handler.spec.ts`, `reputation.int-spec.ts`: cola, hechos, cálculo manual, repetición y entrega atrasada |
| 3.6 | `identidad/application/reviewer-reader.ts`, `infrastructure/reviewer.reader.kysely.ts`; `moderacion/application/review-pattern-handler.ts`, `application/ports.ts`, `domain/review-pattern.ts`, `infrastructure/review-case.store.kysely.ts`, `202611080220_moderacion_casos.ts` | `moderacion/application/review-pattern-handler.spec.ts` y `reputation.int-spec.ts`: umbral, frontera de 24 h, caso privado y deduplicación |
| 3.7 | Ejecución a cargo del supervisor | Pendientes `npm run verify`, integración, grafo, Redocly y CI. No se declaran resultados satisfactorios |


### Nombres exactos de las pruebas escritas

### `backend/src/modules/reputacion/domain/review.spec.ts`

- nace en revisión, normaliza el comentario y registra una vez su evento sin contenido ni fotos
- valida id del celular, estrellas enteras, comentario y máximo de tres fotos distintas

### `backend/src/modules/reputacion/application/reputation-workflows.spec.ts`

- guarda en revisión y registra el evento con la transacción y el reloj de la reseña
- un id propio es idempotente y distingue reseña duplicada de un id ajeno
- exige nivel 1, zona propia y servicio vigente de otro proveedor
- rechaza la cuenta nueva y admite exactamente el umbral de 72 horas
- limita la ventana móvil, incluye las ocultas y el reintento del id no consume cuota
- acepta fotos listas del autor en orden y rechaza las ajenas, pendientes o de otro propósito
- Visto Bueno conserva id y nivel inicial, y dos retiros solicitan un solo recálculo
- la cola vuelve a contar solo reseñas publicadas y vistos verificados de la zona en cada entrega

### `backend/src/modules/directorio/domain/reputation-ranking.spec.ts`

- calcula a mano el puntaje con peso 7 y media 4: (28 + 9) / 9
- con media 4 prioriza 80 reseñas de 4,8 frente a una sola de 5
- el promedio sin reseñas es cero y el puntaje usa la media de la categoría

### `backend/src/modules/directorio/application/reputation-aggregates-handler.spec.ts`

- el manejador usa la media ponderada de toda la categoría y omite el evento ya aplicado
- el manejador rechaza totales incompatibles antes de escribir

### `backend/src/modules/moderacion/application/review-pattern-handler.spec.ts`

- cuatro reseñas no abren caso y la quinta del dispositivo pasa a moderación

### `backend/test/integration/reputation.int-spec.ts`

- crea 201 en revisión y devuelve 200 por clave o id propio con un solo evento
- protege nivel, autoría, zona, vigencia del servicio y edad de la cuenta
- serializa la cuota ante envíos simultáneos y 429 incluye Retry-After
- en dos reseñas simultáneas con distinto id del mismo autor y servicio solo una se guarda
- rechaza la foto ajena y enlaza solo fotos listas propias sin publicar variantes
- revierte reseña, fotos y señal si falla el outbox y permite reintentar la misma clave
- Visto Bueno se conserva, solo suma al ranking desde nivel 2 y se retira sin duplicar trabajos
- recalcula desde reseñas publicadas, obtiene 37/9 y rechaza reenvíos viejos o duplicados
- cinco reseñas del mismo dispositivo en 24 horas abren un solo caso ante reintentos
- valida sesión, clave, ids, calificación y fotos en los contratos de escritura

### `backend/test/integration/reputation-migrations.int-spec.ts`

- publica las tres tablas acordadas y excluye señales, casos y control de eventos
- revierte y reaplica las tres migraciones sin afectar las tablas del directorio

Total: 28 pruebas nuevas declaradas, sin ejecutar; se conserva la cobertura anterior.

## 4. Contrato

### Rutas y esquemas

- `POST /v1/resenas` recibe `NuevaResena` (`id`, `servicioId`, `calificacion`, `comentario?`,
  `fotos?`), devuelve `ResenaPropia` en 201 o 200. Errores de negocio `resena_duplicada`,
  `id_en_uso`, `no_puedes_resenarte`, `fuera_de_tu_zona`, `cuenta_muy_nueva`, `archivo_no_valido`
  y `limite_diario_alcanzado` con `Retry-After`, además de errores comunes de sesión,
  idempotencia, nivel, zona, validación y recurso no encontrado.
- `POST /v1/servicios/{id}/visto-bueno` devuelve 200 `VistoBuenoPropio`; se mantiene el nivel
  registrado al dar el primero. Solo el nivel ≥ 2 de la zona suma al ranking.
- `DELETE /v1/servicios/{id}/visto-bueno` quita la fila propia, 204 si ya no existe. El replay
  con la misma clave devuelve 200, conforme al interceptor existente. No necesita cuerpo.


## 5. Migraciones y publicación

### Tablas y reversión

- `202611080200_reputacion_base.ts`: tablas públicas `reputacion.resenas`,
  `reputacion.resena_fotos` y `reputacion.vistos_buenos`, con `id` y columnas acordadas. Las
  agrega a `powersync` y concede `SELECT` y `USAGE` si existe `powersync_rol`. También crea
  `reputacion.senales_resenas`, privada.
- `202611080210_directorio_control_recalculo.ts`: `directorio.recalculos_reputacion`, privada;
  compara fecha e id del último evento aplicado a cada servicio.
- `202611080220_moderacion_casos.ts`: cola mínima privada `moderacion.casos` para la tarea 3.6,
  con unicidad por tipo e id de contenido. La Parte 5 completa decisiones y auditoría.

`down` revierte las tablas, y en reputación también su membresía de publicación. Las pruebas
escritas hacen el ciclo en transacción y lo revierten para conservar las otras fixtures.


## 6. Variables nuevas

### Configuración documentada

| Variable | Ejemplo y valor por defecto | Uso |
|---|---:|---|
| `MIN_ACCOUNT_AGE_HOURS_TO_REVIEW` | 72 | Horas mínimas desde la creación de la cuenta |
| `MAX_REVIEWS_PER_DAY` | 5 | Reseñas por autor en ventana móvil de 24 horas |

Las dos están en `.env.example` y `shared/config/app-config.ts`; no se agregan secretos.


## 7. Desviaciones y límites

Se conservan las rutas, el cuerpo de reseña, las columnas públicas y la carga de agregados
acordada. La fórmula usa peso 7 y media ponderada de la categoría. La prueba del escenario
80 reseñas frente a una usa media 4; el orden para otras medias depende de la fórmula.

El puerto de fotos y su doble están escritos; el enlace productivo espera a C1, como prevé
el change. La cola mínima de Moderación cubre 3.6 y queda fuera de PowerSync. La publicación
u ocultamiento de reseñas y sus decisiones corresponden a la Parte 5.

Se deja 3.7 pendiente de ejecución por el supervisor. No se declaran pruebas aprobadas.

## 8. Qué debe mirar primero el supervisor

### Revisión prioritaria

- Se conservan el cuerpo de las reseñas, las columnas públicas y la carga exacta acordada de
  `reputacion.agregados_recalculados`. `reputacion.recalculo_solicitado` es un trabajo interno.
  Deja disponible `reputacion.resena_publicada` para el consumidor del Lote C. La publicación
  u ocultamiento de reseñas de la Parte 5 deberá solicitar el mismo recálculo en su transacción.
- Revisar exclusiones de `en_revision` y `oculta`, el contador de nivel al otorgar y la media
  ponderada de la categoría. Con sumas 9 y 11 en 2 y 3 reseñas publicadas respectivamente, la
  media es 4 y el servicio con 2 reseñas obtiene `(7 × 4 + 9) / (7 + 2) = 37/9`.
  El ejemplo de 80 reseñas frente a una de 5 se comprueba con media 4; su orden depende de esa
  media. Se conserva la fórmula acordada sin imponer un orden adicional.
- Revisar el bloqueo por autor en la cuota, la unicidad de reseñas y Visto Bueno, y la unidad
  de trabajo de reseña, fotos, señal y outbox. Hay casos escritos con solicitudes simultáneas
  y con un fallo de outbox antes del commit. El consumidor de agregados ignora eventos iguales
  o más antiguos y deja intacta la versión de edición.
- C1 aún no expone `findOwnedReadyFile` en `media/index.ts`. Se usa el puerto previsto y un
  doble en memoria en pruebas; el adaptador por defecto rechaza referencias no verificadas.
  Revisar con C el enlace real y la prueba de publicación de variantes. No se toca el módulo Media.
- Antifraude usa `dispositivo` de la familia de sesión existente, por su interfaz pública y
  guardado como hash. Se cuentan cinco reseñas en 24 horas, incluida la actual, sin replicar
  ni emitir esa señal. Es una señal para revisión humana, no una prueba de identidad del
  dispositivo. No se amplía el contrato de inicio de sesión ni el cuerpo de la reseña.
- La única preparación de Moderación es la cola necesaria para 3.6. No se agregan sus rutas
  ni se publica automáticamente ninguna reseña. No se modifican `app/`, `infra/`,
  observabilidad ni changes ajenos.


### Verificación y pendientes

Revisión estática de alcance, contratos, diff y espacios con `git diff --check`. Formato
aplicado con el Prettier ya instalado. No se ejecutaron pruebas, linters, comprobaciones de
tipos, builds, migraciones, base de datos, API, workers, Redocly ni grafo.

El supervisor debe ejecutar `npm run verify`, `npm run test:integration`, `npm run graph`,
Redocly y revisar CI. La Parte 3 no marca casillas ni afirma que se haya verificado la CDN o
el Sync Stream del Lote A.


## 9. Comprobación de la regla sobre los mensajes de commit

Salida del comando solicitado sobre `87535d7d234c177c55957665951ea34f95433aff..HEAD`:

```text
0
```

El estado de salida 1 de `grep` indica ausencia de coincidencias; el conteo es cero.

## 10. Publicación y detención

Se subió únicamente `f1-lote-b/parte-3-resenas` con `git push -u origin f1-lote-b/parte-3-resenas`. El SHA remoto coincide con el
local. No se hicieron merge, rebase, cherry-pick, push forzado, borrado de ramas ni PR.
Se conservaron los worktrees de las partes anteriores. No se inició la Parte 4; se espera
el visto bueno de esta entrega.
