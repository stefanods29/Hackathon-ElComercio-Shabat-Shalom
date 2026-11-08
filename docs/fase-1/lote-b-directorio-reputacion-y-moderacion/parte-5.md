# Parte 5 · Entrega para revisión

Rama: `f1-lote-b/parte-5-moderacion`. Base: `f1-lote-b/parte-4-identidad-y-privacidad`,
`aa86b3ce0ddd0cf657324b9342e11c7c1d26b430`. Responsable: JDiazD33.

Se escribieron la implementación y las pruebas de 5.1–5.5. Las comprobaciones de 5.6 quedan a
cargo del supervisor. No se marcaron las casillas de OpenSpec ni se archivó el change.

## Cobertura por tarea

Las rutas de módulo parten de `backend/src/modules/`. Las pruebas de integración parten de
`backend/test/integration/`.

| Tarea | Código y documentos | Pruebas escritas |
|---|---|---|
| 5.1 | `contracts/openapi.yaml` en el primer commit, `moderacion/api/moderation.controller.ts` y `api/schemas.ts` | `moderation.int-spec.ts`: cuerpo, motivos, autorización, cursor y respuestas; Redocly pendiente |
| 5.2 | Tres migraciones descritas abajo, `solidaridad/infrastructure/tables.ts` y `post.repository.kysely.ts` | `migrations.int-spec.ts` y `moderation.int-spec.ts`: reversión, publicación privada y filtros |
| 5.3 | `moderacion/application/report-content.ts`, `screen-content.ts`, `image-moderation-registry.ts`, `moderation-jobs.ts`, `domain/screening.ts` y lector de nivel público de Identidad | `report-content.spec.ts`, `screen-content.spec.ts`, `moderation.int-spec.ts` y `reputation.int-spec.ts`: deduplicación, texto, imágenes, nivel y antifraude |
| 5.4 | `moderacion/application/decide-case.ts`, `read-moderation.ts`, `moderation-events.ts`, `moderation-jobs.ts`, `infrastructure/moderation.store.kysely.ts` y adaptadores `*-moderation.kysely.ts` de Solidaridad, Directorio y Reputación | `moderation.int-spec.ts`: denuncia, cola, auditoría, ocultamiento, restauración, orden de eventos y recálculo; `backend/src/shared/queues/job-handler.registry.spec.ts`: suscriptores |
| 5.5 | `moderacion/application/moderation-policy-registration.ts`, `moderacion/index.ts`, `infrastructure/moderation.store.kysely.ts`, `read-moderation.ts`, `backend/src/shared/moderation/publication-policy.ts` y los repositorios de escritura de los dueños | `moderation.int-spec.ts): duración, permisos, p90 y persistencia de la primera revisión |
| 5.6 | Ejecución a cargo del supervisor | Pendientes `npm run verify`, `npm run test:integration`, `npm run graph`, Redocly, `openspec validate --all --strict` y CI |

La exportación y el borrado de cuenta incluyen las denuncias mediante el participante
`moderacion/infrastructure/moderation-personal-data.kysely.ts`.

## Contrato

| Ruta | Esquemas y reglas |
|---|---|
| `POST /v1/denuncias` | `NuevaDenuncia` → 201 `DenunciaPropia`; 200 al repetir. Con sesión desde nivel 0 e `Idempotency-Key`. Tipos: `publicacion`, `resena`, `servicio`, `foto`, `proveedor`. Motivos: `spam`, `ofensivo`, `informacion_falsa`, `datos_personales`, `peligroso`, `otro`. Detalle opcional de hasta 500 caracteres. |
| `GET /v1/moderacion/casos` | `estado`, `cursor` y `limite` → `PaginaDeCasos`. Solo rol `moderador`. El orden es fecha de creación e id. La cola no devuelve teléfonos, detalles ni justificaciones privadas. |
| `POST /v1/moderacion/casos/{id}/decision` | `DecisionDeModeracion` → 200 `CasoDeModeracion`. Solo `moderador`, motivo obligatorio e `Idempotency-Key`. Acciones `publicar`, `ocultar`, `restaurar`, `descartar` y `sancionar`. |
| `GET /v1/moderacion/metricas` | `desde` inclusivo, `hasta` exclusivo → `MetricasDeModeracion`. Solo `administrador`. Cuenta casos por creación, casos todavía pendientes y p90 de primera revisión humana en segundos, nulo sin revisiones. Por defecto, últimos siete días. |

Errores estables: `validacion`, `rol_requerido`, `recurso_no_encontrado`, `id_en_uso` y
`cuenta_suspendida`. Se conservan los errores compartidos de sesión e idempotencia. No se
cambia la forma de las respuestas del muro, el directorio ni la reputación.

## Migraciones y PowerSync

- `202611080400_moderacion_denuncias_decisiones_y_sanciones.ts` amplía `moderacion.casos`
  (existente desde la Parte 3) y crea `denuncias`, `decisiones`, `sanciones` y `visibilidad`.
  Todas son privadas.
- `202611080410_solidaridad_visibilidad_moderacion.ts` agrega `publicaciones.oculta_en`, nula
  por defecto, para la API y los dos streams del muro.
- `202611080420_directorio_visibilidad_individual.ts` agrega una marca interna que distingue
  el ocultamiento individual de un servicio del ocultamiento heredado del proveedor. El
  filtro público existente sigue consultando `servicios.oculto_en`.
- No se agregan tablas a `powersync` ni permisos de publicación. El Lote A ya añadió
  `oculta_en IS NULL` a ambos streams del muro en su rama de datos públicos (`d5ea4d5`).
  Falta ejecutar la comprobación con ambas ramas integradas.

No hay variables nuevas en `.env.example`.

## Revisión prioritaria

1. Aplicar una decisión reciente antes que la anterior, reenviar ambas y comprobar que el
   muro, directorio, reseñas y fotos conservan el estado correcto. La API pública del muro
   y el directorio conserva la publicación inicial; si el filtro deriva el contenido a
   revisión, el ocultamiento se aplica mediante el trabajo. Las reseñas nacen en revisión.
2. Revisar que la sanción y el evento de ocultamiento se guarden con la decisión, que el
   límite sea de siete días y que solo los moderadores puedan decidir. El p90 cuenta solo
   primeras revisiones humanas, no cambios posteriores ni aprobaciones automáticas.
3. Comprobar el consumidor de archivos del Lote C. En esta base, Media todavía no ofrece
   un inspector real. El puerto se puede registrar y las pruebas usan un doble; sin
   inspector, las imágenes van a revisión. La retirada de variantes de la CDN y los
   avisos reales se verifican al integrar C. No se cambian Media, la app ni infraestructura.
4. Verificar que las justificaciones privadas no se copien al outbox ni a la cola. El
   campo `motivo` del evento es un código público. La reseña se recalcula al entrar o salir
   del estado publicado, y el evento de primera publicación no se repite al restaurarla.

Se hizo revisión estática del diff y se aplicó formato con el Prettier ya instalado. No se
ejecutaron pruebas, backend, migraciones, base de datos, chequeo de tipos, lint, builds,
Redocly, el grafo, `openspec validate` ni los Sync Streams.

## Pruebas escritas y actualizadas (nombres exactos)

### `backend/src/modules/moderacion/application/report-content.spec.ts`

- abre un caso y registra un solo evento sin el detalle al repetir el identificador propio
- distingue identificador ajeno o alterado de una repetición propia

### `backend/src/modules/moderacion/application/screen-content.spec.ts`

- detecta insultos con tilde y puntuación sin marcar palabras por coincidencia parcial
- consulta cada imagen una vez antes de la reputación y deriva imágenes dudosas o sin verificar
- permite la reseña limpia del vecino de nivel 2 y deriva cuentas sin confianza o sancionadas
- abre revisión por patrón desde la quinta reseña del mismo dispositivo

### `backend/src/modules/directorio/application/directory-workflows.spec.ts`

- emite un solo evento de moderación al publicar un perfil de proveedor

### `backend/src/shared/queues/job-handler.registry.spec.ts`

- entrega un evento al dueño y a su suscriptor sin reemplazar al primero
- no entrega a suscriptores un evento que el dueño identifica como obsoleto

### `backend/test/integration/moderation.int-spec.ts`

- registra una denuncia de nivel 0, oculta el muro con auditoría y restaura aunque llegue un evento antiguo
- envía al moderador publicaciones dudosas del muro y permite decidir su publicación
- publica reseñas limpias automáticamente, mantiene los insultos en revisión y recalcula al decidir
- usa el puerto de imágenes y oculta o restaura una foto sin alterar la reseña publicada
- al restaurar un proveedor mantiene oculto el servicio que tiene su propia decisión
- sanciona durante siete días y bloquea la publicación en los tres módulos hasta el vencimiento
- exporta denuncias propias y quita su detalle cuando se borra la cuenta del denunciante
- pagina por estado sin repetir casos y muestra el p90 de primeras revisiones solo a administradores

### `backend/test/integration/migrations.int-spec.ts`

- revierte y reaplica moderación sin publicar sus tablas privadas

### `backend/test/integration/reputation.int-spec.ts`

- cinco reseñas del mismo dispositivo en 24 horas abren un solo caso ante reintentos
