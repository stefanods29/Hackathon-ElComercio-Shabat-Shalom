# Parte 4 · Entrega para revisión

Rama: `f1-lote-b/parte-4-identidad-y-privacidad`. Base: `f1-lote-b/parte-3-resenas`,
`d7973dd4dc5c7ee64d654762f037db34862399c9`. Responsable: JDiazD33.

Se escribieron las tareas 4.1–4.7. La aprobación del ADR y la verificación 4.8 quedan a cargo
del supervisor. Las casillas de OpenSpec siguen intactas.

## Cobertura por tarea

Las rutas de módulos abreviadas comienzan en `backend/src/modules/`. Las de integración
comienzan en `backend/test/integration/`.

| Tarea | Código y documentos | Pruebas escritas |
|---|---|---|
| 4.1 | [ADR 0011](../../adr/0011-confirmacion-de-residencia.md) y [su índice](../../adr/README.md) | Revisión del equipo pendiente |
| 4.2 | `contracts/openapi.yaml` en el primer commit; `identidad/api/privacy.controller.ts`, `privacy.schemas.ts` y `zones.controller.ts` | `identity-privacy.int-spec.ts`, `zones.int-spec.ts`; Redocly pendiente |
| 4.3 | `identidad/infrastructure/migrations/202611080300_identidad_residencia_y_privacidad.ts`, `infrastructure/tables.ts` | `migrations.int-spec.ts`: reversión, reaplicación y publicación privada |
| 4.4 | `identidad/application/choose-zone.ts`, `identity-events.ts`, `infrastructure/residence.store.kysely.ts`, `domain/residence.ts`; consumidor de cambio de zona en Directorio | `identity-privacy.int-spec.ts`, `zones.int-spec.ts`, `identidad/domain/residence.spec.ts` |
| 4.5 | `identidad/application/record-residence.ts`, `residence-store.ts`, `identity-jobs.ts`, `domain/residence.ts`; programación en `backend/src/workers/workers.module.ts` | `identity-privacy.int-spec.ts` y `identidad/domain/residence.spec.ts`: ventana, días distintos, rechazo sin consentimiento, confirmación, avales y retención |
| 4.6 | `identidad/domain/consents.ts`, `application/manage-consents.ts`, `application/manage-account-privacy.ts`, `infrastructure/identity-personal-data.kysely.ts`, `backend/src/shared/privacy/personal-data.registry.ts` y participantes de cada módulo | `identity-privacy.int-spec.ts`: versiones, oposición, rectificación y exportación |
| 4.7 | `identidad/application/manage-account-privacy.ts`, `account-privacy-store.ts`, `identity-jobs.ts`, `infrastructure/identity-personal-data.kysely.ts`, `backend/src/shared/auth/account-access.ts`, `auth.guard.ts` y adaptadores de datos personales de Directorio, Reputación, Solidaridad, Emergencias, Notificaciones y Compartido | `identity-privacy.int-spec.ts`: revocación, rollback, reintentos, copias tardías y búsqueda de teléfono y nombre en todas las tablas de aplicación |
| 4.8 | Ejecución a cargo del supervisor | Pendientes `npm run verify`, `npm run test:integration`, `npm run graph`, Redocly y CI |

## Contrato

| Ruta | Solicitud y respuesta |
|---|---|
| `PUT /v1/yo/zona` | `EleccionZona` → 200 `Sesion`. Misma zona conserva nivel; cambio prematuro: 409 `cambio_de_zona_muy_pronto` con `disponibleDesde` |
| `POST /v1/yo/residencia/presencia` | `PresenciaDeResidencia` → 200 `NivelDeResidencia`; 403 `consentimiento_requerido` o `zona_requerida`; 422 `fecha_de_presencia_invalida` |
| `POST /v1/vecinos/{id}/residencia` | `ConfirmacionDeResidencia` con `motivo` y `nivel` opcional (1 por defecto) → 200 `NivelDeResidencia`; exige `moderador` |
| `POST /v1/vecinos/{id}/aval` | Sin cuerpo → 200 `NivelDeResidencia`; nivel 2, misma zona y 403 `no_puedes_avalarte` si intenta avalarse |
| `GET /v1/yo/consentimientos` | 200, lista de `EstadoDeConsentimiento`, con finalidad, versión vigente y última decisión |
| `POST /v1/yo/consentimientos` | `DecisionDeConsentimiento` → 200 `EstadoDeConsentimiento`; 409 `version_de_consentimiento_desactualizada` con `versionVigente` |
| `GET /v1/yo/datos` | 200 `ExportacionDeDatosPersonales`, agrupada por módulo y con `Cache-Control: no-store` |
| `PATCH /v1/yo` | `RectificacionDePerfil` con `nombreVisible` → 200 con el nombre actualizado |
| `DELETE /v1/yo` | Sin cuerpo → 202; la sesión deja de servir para solicitudes posteriores |

Las escrituras exigen `Idempotency-Key`. La exportación muestra una lista vacía de denuncias
porque el esquema de la Parte 3 solo tiene casos automáticos sin datos del denunciante. La Parte 5
incorporará los registros de denuncias al participante de Moderación.

## Migración y variables

`202611080300_identidad_residencia_y_privacidad.ts` crea `identidad.consentimientos`,
`identidad.presencias`, `identidad.avales` y `identidad.confirmaciones`, y agrega
`identidad.usuarios.zona_elegida_en`. Reutiliza `eliminado_en` de Fase 0 y permite que solo las
cuentas eliminadas pierdan el teléfono. Para las zonas ya asignadas usa `actualizado_en` como
aproximación al día de elección. Al revertir, el teléfono original no se reconstruye: un valor
sintético único conserva la restricción anterior en las filas ya anonimizadas.

No se agrega ninguna tabla a `powersync` ni ningún permiso nuevo. No hay variables nuevas en
`.env.example`; las dos versiones de consentimiento empiezan en 1 en la configuración de Identidad.

## Revisión prioritaria

1. Verificar el bloqueo de filas entre la cancelación y las escrituras que guardan datos
   personales. La baja, la revocación de sesiones y el evento de outbox se confirman juntos.
   Los participantes del trabajo comparten otra transacción y pueden repetirse sin volver a
   procesar una cuenta ya anonimizada. Las copias de idempotencia vinculadas a una cuenta
   eliminada tampoco se vuelven a guardar.
2. Revisar la limpieza de teléfono, nombre, ubicación privada, sesiones, OTP, datos de
   notificaciones, textos y fotos de reseñas. Las claves necesarias para referencias se
   conservan; quedan las estrellas de reseñas ya públicas, sin comentario ni fotos. Al quitar
   Visto Bueno se solicita el recálculo del servicio. No se modifican las columnas públicas
   acordadas.
3. Verificar la ventana de presencia en Lima, el límite de zona, la oposición inmediata y el
   reinicio de nivel. Un token de PowerSync ya emitido se valida en ese servicio hasta su
   expiración; la cancelación impide obtener credenciales nuevas y bloquea los tokens de la API.
   No se cambia el verificador externo ni los Sync Streams.
4. Revisar las decisiones que el diseño dejó abiertas: nivel manual opcional para arrancar
   los avales, respuestas de nivel en las tres escrituras de residencia y fechas de zonas
   anteriores a la migración. La finalidad de uso del servicio se publica como obligatoria
   y admite registrar su decisión; no se añade una condición general de acceso a las rutas
   anteriores. La finalidad de presencia se exige antes de tratar cualquier informe.

Se hizo revisión estática del diff y se aplicó formato con el Prettier ya instalado. No se
ejecutaron las pruebas, el backend, las migraciones, la base de datos, el chequeo de tipos,
linters, builds, Redocly ni el grafo.

## Pruebas escritas y actualizadas (nombres exactos)

### `backend/src/modules/identidad/domain/residence.spec.ts`

- permite cambiar de zona en el instante exacto en que se cumplen 30 días
- cuenta 14 fechas locales en Lima y descarta las de la zona anterior

### `backend/test/integration/identity-privacy.int-spec.ts`

- conserva el nivel al elegir la misma zona y devuelve disponibleDesde si el cambio es temprano
- cambia de zona en el límite, baja al nivel 0 y retira los servicios de la zona anterior
- sin consentimiento vigente no trata la presencia ni guarda un evento
- promueve por tres días distintos dentro de 14 y rechaza coordenadas y fechas fuera de la ventana
- el trabajo diario borra presencias de 30 días y conserva las más recientes
- audita la confirmación manual de nivel 1 y permite al moderador iniciar el nivel 2
- cuenta dos avales válidos y distintos y rechaza autoavales, otra zona o nivel insuficiente
- devuelve finalidades y versiones, registra oposición y conserva el nivel confirmado
- rectifica el nombre y exporta los datos propios de cada módulo sin credenciales
- revoca todas las sesiones al devolver 202 y tras el trabajo no quedan teléfono ni nombre en ninguna tabla

### `backend/test/integration/zones.int-spec.ts`

- lista públicamente las zonas sin el polígono
- elige la zona, acepta la misma zona y actualiza los tokens de acceso y sincronización
- responde 404 si la zona no existe
- solo asigna una zona cuando dos elecciones distintas compiten

### `backend/test/integration/migrations.int-spec.ts`

- revierte y reaplica las tablas privadas de residencia sin recuperar un teléfono borrado
- la publicación de PowerSync incluye solo las tablas que deben llegar a los celulares
