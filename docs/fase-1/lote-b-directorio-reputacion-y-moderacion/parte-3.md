# Parte 3 · Entrega para revisión

Rama: `f1-lote-b/parte-3-resenas`. Base: `f1-lote-b/parte-2-busqueda`,
`87535d7d234c177c55957665951ea34f95433aff`. Responsable: JDiazD33.

Código de 3.1–3.6 escrito. La verificación 3.7 queda para el supervisor y las casillas de
OpenSpec siguen intactas. Los archivos de prueba son evidencia de cobertura escrita, sin ejecución.

## Cobertura por tarea

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

## Contrato

- `POST /v1/resenas` recibe `NuevaResena` (`id`, `servicioId`, `calificacion`, `comentario?`,
  `fotos?`), devuelve `ResenaPropia` en 201 o 200. Errores de negocio `resena_duplicada`,
  `id_en_uso`, `no_puedes_resenarte`, `fuera_de_tu_zona`, `cuenta_muy_nueva`, `archivo_no_valido`
  y `limite_diario_alcanzado` con `Retry-After`, además de errores comunes de sesión,
  idempotencia, nivel, zona, validación y recurso no encontrado.
- `POST /v1/servicios/{id}/visto-bueno` devuelve 200 `VistoBuenoPropio`; se mantiene el nivel
  registrado al dar el primero. Solo el nivel ≥ 2 de la zona suma al ranking.
- `DELETE /v1/servicios/{id}/visto-bueno` quita la fila propia, 204 si ya no existe. El replay
  con la misma clave devuelve 200, conforme al interceptor existente. No necesita cuerpo.

## Migraciones y publicación

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

## Variables nuevas

| Variable | Ejemplo y valor por defecto | Uso |
|---|---:|---|
| `MIN_ACCOUNT_AGE_HOURS_TO_REVIEW` | 72 | Horas mínimas desde la creación de la cuenta |
| `MAX_REVIEWS_PER_DAY` | 5 | Reseñas por autor en ventana móvil de 24 horas |

Las dos están en `.env.example` y `shared/config/app-config.ts`; no se agregan secretos.

## Decisiones y revisión prioritaria

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

## Verificación de esta entrega

Revisión estática de alcance, contratos, diff y espacios con `git diff --check`. Formato
aplicado con el Prettier ya instalado. No se ejecutaron pruebas, linters, comprobaciones de
tipos, builds, migraciones, base de datos, API, workers, Redocly ni grafo.

El supervisor debe ejecutar `npm run verify`, `npm run test:integration`, `npm run graph`,
Redocly y revisar CI. La Parte 3 no marca casillas ni afirma que se haya verificado la CDN o
el Sync Stream del Lote A.

## Pruebas escritas (nombres exactos)

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
