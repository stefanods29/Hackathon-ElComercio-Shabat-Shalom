# Fase 1 · Lote B · Entrega de la Parte 4

## 1. Rama, base y SHA final

- Rama: `f1-lote-b/parte-4-identidad-y-privacidad`
- Base: `f1-lote-b/parte-3-resenas`, `d7973dd4dc5c7ee64d654762f037db34862399c9`
- SHA final: `aa86b3ce0ddd0cf657324b9342e11c7c1d26b430`
- Estado de la guía: **Lista para revisión**. Se detuvo el trabajo antes de la Parte 5.

## 2. Commits y alcance del diff

`git log --oneline d7973dd4dc5c7ee64d654762f037db34862399c9..HEAD`

```text
aa86b3c Documenta la decisión de residencia y prepara la entrega para revisión
024509d Cubre la residencia y los derechos del vecino por HTTP
f5d4c07 Implementa la residencia, el consentimiento y el borrado de cuentas
4918bc7 Agrega las tablas privadas de residencia y consentimiento
7ad88ad Define el contrato de residencia y privacidad del vecino
```

`git diff --stat d7973dd4dc5c7ee64d654762f037db34862399c9..HEAD`

```text
 backend/src/modules/directorio/directory.module.ts |   2 +
 .../directory-personal-data.kysely.ts              |  94 ++++
 .../infrastructure/directory.repository.kysely.ts  |   9 +-
 .../src/modules/emergencias/emergencies.module.ts  |   3 +-
 .../emergency-personal-data.kysely.ts              |  32 ++
 .../modules/identidad/api/privacy.controller.ts    | 106 ++++
 .../src/modules/identidad/api/privacy.schemas.ts   |  25 +
 .../identidad/application/account-privacy-store.ts |  11 +
 .../modules/identidad/application/choose-zone.ts   |  75 ++-
 .../identidad/application/create-session.ts        |  10 +-
 .../identidad/application/identity-events.ts       |  40 ++
 .../modules/identidad/application/identity-jobs.ts |  40 ++
 .../application/manage-account-privacy.ts          |  69 +++
 .../identidad/application/manage-consents.ts       |  69 +++
 backend/src/modules/identidad/application/ports.ts |   5 -
 .../identidad/application/record-residence.ts      | 184 +++++++
 .../identidad/application/refresh-session.spec.ts  |   3 +-
 .../identidad/application/residence-store.ts       |  65 +++
 .../application/sign-in-with-firebase.spec.ts      |   9 +-
 .../identidad/application/verify-otp.spec.ts       |   9 +-
 backend/src/modules/identidad/domain/consents.ts   |   7 +
 .../src/modules/identidad/domain/residence.spec.ts |  31 ++
 backend/src/modules/identidad/domain/residence.ts  |  53 ++
 backend/src/modules/identidad/identity.module.ts   |  24 +-
 backend/src/modules/identidad/index.ts             |   1 +
 .../identity-personal-data.kysely.ts               | 236 +++++++++
 ...2611080300_identidad_residencia_y_privacidad.ts |  92 ++++
 .../infrastructure/residence.store.kysely.ts       | 196 ++++++++
 .../src/modules/identidad/infrastructure/tables.ts |  40 +-
 .../infrastructure/user.repository.kysely.ts       |  23 +-
 .../application/moderation-personal-data.ts        |  23 +
 .../src/modules/moderacion/moderation.module.ts    |   2 +
 .../infrastructure/device.repository.ts            |  16 +-
 .../notification-personal-data.kysely.ts           |  37 ++
 .../modules/notificaciones/notifications.module.ts |   2 +
 .../reputation-personal-data.kysely.ts             |  91 ++++
 .../infrastructure/reputation.repository.kysely.ts |   5 +
 .../src/modules/reputacion/reputation.module.ts    |   2 +
 .../infrastructure/post.repository.kysely.ts       |   9 +-
 .../solidarity-personal-data.kysely.ts             |  86 ++++
 .../src/modules/solidaridad/solidarity.module.ts   |   2 +
 backend/src/shared/auth/account-access.ts          |  41 ++
 backend/src/shared/auth/auth.guard.ts              |  13 +-
 .../idempotency/idempotency-store.postgres.ts      |  49 +-
 .../src/shared/privacy/personal-data.registry.ts   |  41 ++
 backend/src/shared/privacy/shared-personal-data.ts |  42 ++
 backend/src/shared/shared.module.ts                |  23 +-
 backend/src/workers/workers.module.ts              |   7 +
 .../test/integration/identity-privacy.int-spec.ts  | 554 +++++++++++++++++++++
 backend/test/integration/migrations.int-spec.ts    |  46 ++
 backend/test/integration/zones.int-spec.ts         |  15 +-
 contracts/openapi.yaml                             | 280 ++++++++++-
 docs/adr/0011-confirmacion-de-residencia.md        |  37 ++
 docs/adr/README.md                                 |   1 +
 .../README.md                                      |   2 +-
 .../parte-4.md                                     | 111 +++++
 56 files changed, 2994 insertions(+), 106 deletions(-)
```

## 3. Tareas y pruebas escritas

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

La implementación y los casos de 4.1–4.7 se entregan sin ejecutar el código. Faltan la
aprobación del ADR y las comprobaciones de 4.2–4.8 que corresponden al supervisor.
No se marcaron casillas de OpenSpec.

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

### `backend/src/modules/identidad/application/refresh-session.spec.ts` (dobles ajustados al control de cuenta activa)

- rota el secreto opaco, conserva familia y dispositivo, y guarda solo HMAC
- relee zona, nivel y roles antes de emitir los tokens nuevos
- persiste la revocación de toda la familia antes de lanzar el error de reutilización
- rechaza un token desconocido sin crear filas
- rechaza al alcanzar exactamente la fecha de vencimiento
- rechaza una familia revocada aunque el refresh no se haya consumido
- revoca y no emite tokens si la cuenta dejó de estar disponible
- revierte la rotación completa si falla la firma y permite usar el refresh original

### `backend/src/modules/identidad/application/sign-in-with-firebase.spec.ts` (dobles ajustados al control de cuenta activa)

- abre la sesión de siempre para el teléfono que confirmó Firebase
- reutiliza al vecino que ya existía
- rechaza un token inválido sin crear al vecino
- rechaza un token de hace más de 10 minutos

### `backend/src/modules/identidad/application/verify-otp.spec.ts` (dobles ajustados al control de cuenta activa)

- acepta el código correcto, registra nivel 0 y emite acceso con refresh
- rechaza un código vencido con el mismo codigo_invalido
- rechaza la reutilización y no crea otra sesión
- persiste cada intento fallido y bloquea después del máximo

## 4. Contrato

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

## 5. Migración y PowerSync

`202611080300_identidad_residencia_y_privacidad.ts` crea `identidad.consentimientos`,
`identidad.presencias`, `identidad.avales` y `identidad.confirmaciones`, y agrega
`identidad.usuarios.zona_elegida_en`. Reutiliza `eliminado_en` de Fase 0 y permite que solo las
cuentas eliminadas pierdan el teléfono. Para las zonas ya asignadas usa `actualizado_en` como
aproximación al día de elección. Al revertir, el teléfono original no se reconstruye: un valor
sintético único conserva la restricción anterior en las filas ya anonimizadas.

No se agrega ninguna tabla a `powersync` ni ningún permiso de publicación.

## 6. Variables de entorno

Ninguna variable nueva. Las dos finalidades tienen versión 1 en la configuración del módulo
Identidad. `.env.example` no cambia.

## 7. Decisiones y desviaciones

- Se conserva `eliminado_en` de Fase 0. Para los vecinos con una zona existente, la migración
  usa `actualizado_en` para establecer el primer límite porque no había historial de elecciones.
- El diseño requiere iniciar manualmente los primeros niveles 2. El contrato agrega para ello
  `nivel` opcional a la confirmación manual; por defecto asigna 1.
- `uso_del_servicio` se publica como finalidad obligatoria y se puede registrar su decisión.
  No se introduce una barrera global de acceso para los clientes anteriores. El tratamiento
  de presencia sí exige una aceptación vigente.
- En esta parte no hay denuncias persistidas. Moderación devuelve `denuncias: []` hasta que
  exista ese esquema; sus casos automáticos no guardan teléfono ni nombre.
- Los tokens ya emitidos para PowerSync vencen en el verificador externo con su TTL existente.
  La revocación es inmediata en la API, para los refresh tokens y para nuevas credenciales
  de sincronización. No se cambia la infraestructura de PowerSync.

## 8. Revisión prioritaria

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

## 9. Comprobación de mensajes de commit

`git log d7973dd4dc5c7ee64d654762f037db34862399c9..HEAD --format=%B | grep -icE 'co-authored|claude|anthropic|chatgpt|openai|copilot'`

```text
0
```

## 10. Entrega de rama

Se subió únicamente `f1-lote-b/parte-4-identidad-y-privacidad` con `git push -u origin f1-lote-b/parte-4-identidad-y-privacidad`. El remoto devolvió
`aa86b3ce0ddd0cf657324b9342e11c7c1d26b430` para `refs/heads/f1-lote-b/parte-4-identidad-y-privacidad`. El árbol local está limpio y sigue esa rama remota.
No se hizo merge, rebase, cherry-pick, push forzado ni se abrió un PR.
