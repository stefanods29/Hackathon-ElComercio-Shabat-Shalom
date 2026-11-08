# Parte 1 · Entrega para revisión

Rama: `f1-lote-b/parte-1-directorio`. Base: `origin/f1-lote-a/apertura`,
`cb6797cd3cc2f7f32ab2def06359a581bd2f1fec`. Responsable: JDiazD33.

Código de las tareas 1.1–1.5 escrito para revisión. Ninguna tarea se marca aprobada: el supervisor
conserva todas las casillas de `tasks.md`. La tarea 1.6 requiere su ejecución y permanece pendiente.

## Cobertura por tarea

Las rutas de esta tabla son relativas a la raíz del repositorio.

| Tarea | Código escrito | Pruebas escritas |
|---|---|---|
| 1.1 | `contracts/openapi.yaml`: contrato inicial en el primer commit `510bbf5` | `backend/test/integration/directory.int-spec.ts`: categorías, perfil, publicación 201/200, edición/versiones, retiro, sesión/cabecera, validación; nombres exactos más abajo. Redocly pendiente |
| 1.2 | `backend/src/modules/directorio/infrastructure/migrations/202611080100_directorio_base.ts`, `infrastructure/tables.ts` | `backend/test/integration/directory-migrations.int-spec.ts` (publicación/permisos y ciclo down/up); actualización de expectativas de `migrations.int-spec.ts` |
| 1.3 | `backend/src/modules/directorio/domain/service.ts`, `domain/provider-profile.ts`; `application/ports.ts`, `authorization.ts`, `save-provider.ts`, `publish-service.ts`, `edit-service.ts`, `withdraw-service.ts`, `read-directory.ts` | `domain/service.spec.ts`, `domain/provider-profile.spec.ts`, `application/directory-workflows.spec.ts` junto a esos archivos: reglas, reloj fijo, reintentos y carreras |
| 1.4 | `backend/src/modules/directorio/infrastructure/directory.repository.kysely.ts`, `directory.repository.memory.ts`; `api/directory.controller.ts`, `api/schemas.ts`, `directory.module.ts`, `index.ts` | `backend/test/integration/directory.int-spec.ts`; pruebas unitarias de casos de uso con adaptador en memoria. Privacidad, 401/403/409, escritura idempotente, carreras y rollback real escrito |
| 1.5 | `backend/src/modules/directorio/application/zone-changed-handler.ts`, `backend/src/workers/workers.module.ts`, `backend/scripts/seed-data.ts` | `application/zone-changed-handler.spec.ts` con `InMemoryJobQueue`; casos HTTP del evento y de los servicios de demostración en `directory.int-spec.ts` |
| 1.6 | Sin ejecución por la modalidad de este encargo | Pendientes tipos, pruebas unitarias/integración, lint, build, grafo, Redocly y CI. No se declara resultado satisfactorio |

## Contrato

- `GET /v1/categorias` → `{ datos: Categoria[] }`, con sesión.
- `PUT /v1/yo/proveedor` → `GuardarProveedor` / `Proveedor`, nivel 1 y zona.
- `POST /v1/servicios` → `NuevoServicio` / `Servicio`, 201 al crear o 200 para un id propio.
- `PUT /v1/servicios/{id}` → `EditarServicio` / `Servicio`, dueño y `versionVista`.
- `DELETE /v1/servicios/{id}` → retiro lógico, dueño, 204 incluso retirado previamente.
- `GET /v1/proveedores/{id}` → `PerfilDeProveedor`, sin contacto ni ubicación privada.

Esquemas añadidos: `Categoria`, `GuardarProveedor`, `Proveedor`, `PerfilDeProveedor`,
`UbicacionDeServicio`, `DatosDeServicio`, `NuevoServicio`, `EditarServicio` y `Servicio`.
Códigos específicos: `id_en_uso`, `conflicto_de_version` con `versionEsperada`/`versionActual`,
`no_eres_el_dueno`, `nivel_de_confianza_insuficiente`, `sin_zona`, `categoria_invalida`,
`servicio_retirado`, además de validación/autenticación/recurso no encontrado y errores compartidos
de idempotencia. No se añade `GET /v1/servicios`: corresponde a la Parte 2.

## Migración y datos

`202611080100_directorio_base.ts` crea categorías, proveedores y servicios, los índices GiST de
ubicación y GIN de atributos, las columnas públicas acordadas y los agregados en cero. Publica
solo `directorio.categorias`, `directorio.proveedores` y `directorio.servicios` en `powersync`.
Concede `USAGE`/`SELECT` a `powersync_rol` únicamente si existe. `down` retira las tres tablas de
la publicación y elimina el esquema. La prueba down/up usa una transacción que se revierte para
conservar los datos de los demás archivos.

Se siembran seis categorías con ids estables y tres servicios ficticios de Beto, Ana y Elena.
La semilla reutiliza el redondeo público del dominio; repetirla no duplica ni reactiva servicios.
No hay variables nuevas de entorno ni cambios en `.env.example`.

## Decisiones y puntos que revisar primero

- Los nombres de las tablas y columnas públicas coinciden con las decisiones 1 de B y 3 de A.
  El ADR 0010 no viene en la base de apertura; se leyó desde
  `origin/f1-lote-a/parte-1-datos-publicos`, sin integrar esa rama. Coincide con el redondeo de
  tres decimales que ya exigen ambos changes.
- No hay cambios al diseño del modelo ni a las rutas acordadas. La función de texto y la columna
  `busqueda` se incorporarán con la migración de la Parte 2, como pide la tarea 2.2.
- El retiro repetido con otra clave sigue devolviendo 204. Con la misma clave, el interceptor
  compartido devuelve 200 con `Idempotent-Replayed`, conforme al comportamiento existente de
  toda la API y de la baja de dispositivos. El contrato y las pruebas distinguen ambos casos.
- Revisar el almacenamiento separado de ubicación privada y copia pública, la retirada de la
  aceptación de ubicación exacta y la proyección explícita de los DTO.
- Revisar la creación transaccional con outbox, `INSERT ON CONFLICT`, los bloqueos por proveedor y
  la comparación de versión: hay pruebas escritas para solicitudes simultáneas y para rollback.
- El futuro emisor de `identidad.zona_cambiada` (Parte 4) debe usar `agregadoId` para el vecino y
  `carga.zonaAnteriorId` para su zona anterior. El manejador no mueve el perfil ni modifica los
  servicios en la zona nueva. Está registrado en los workers y probado con la cola en memoria.
- El tamaño de atributos se valida en bytes de JSON UTF-8 en API y dominio. La base exige objeto
  JSON; los agregados y las marcas de ocultamiento no son campos editables por el vecino.

## Verificación de esta entrega

Se revisaron los archivos por lectura, las diferencias contra los diseños/specs, el alcance de
rutas modificadas y los espacios con `git diff --check`. Se aplicó formato con el Prettier ya
instalado, sin instalar paquetes ni ejecutar el código de la aplicación.

Por instrucción del encargo **no se ejecutaron pruebas, linters, comprobaciones de tipos,
builds, migraciones, base de datos, API ni workers**. Tampoco se ejecutó `npm run graph` ni
Redocly. Ninguna prueba de esta entrega se presenta como aprobada. El supervisor debe ejecutar
los comandos ya documentados en `CONTRIBUTING.md`: `npm run verify`,
`npm run test:integration`, `npm run graph` y Redocly, y revisar CI y los accesos de PowerSync.
No hay cambios de `app/`, `infra/`, observabilidad ni de los changes ajenos.

## Pruebas escritas (nombres exactos)

### `backend/src/modules/directorio/domain/service.spec.ts`

- nace en versión 1, con agregados en cero y un único evento público sin ubicación
- conserva la ubicación privada y redondea únicamente la copia pública
- muestra el local solo con aceptación explícita y vuelve a redondear al retirarla
- solo el dueño edita o retira, incluso después del retiro
- una versión vieja no cambia el servicio y explica ambas versiones
- editar conserva los agregados de reputación y las marcas de moderación
- el retiro es idempotente, no cambia la fecha ni la versión al repetir y no resucita
- exige UUIDv7 y valida título, ubicación, categoría, radio y descripción
- limita los atributos a 4 KB en UTF-8, contando los bytes de las tildes
- no permite que una referencia externa cambie la ubicación o los atributos

### `backend/src/modules/directorio/domain/provider-profile.spec.ts`

- crea el perfil del vecino, normaliza textos y conserva su fecha al actualizar
- solo el dueño cambia el perfil y su zona
- exige nombre público de 2 a 60 y descripción de hasta 500 caracteres

### `backend/src/modules/directorio/application/directory-workflows.spec.ts`

- guarda el perfil propio y lo actualiza sin duplicarlo
- perfil y publicación exigen nivel 1 y una zona
- crea el servicio y registra el evento con la misma transacción y el reloj fijo
- el mismo id propio devuelve el original sin alterar el cuerpo ni duplicar el evento
- reconoce el id insertado por una carrera sin emitir un segundo evento
- exige perfil vigente en la zona y categoría existente
- editar comprueba dueño, versión y categoría y detecta la carrera del repositorio
- retirar es idempotente, sale del perfil y publicar el mismo id no lo resucita
- el perfil excluye servicios ocultos o de otra zona y no expone proveedores ocultos
- editar, retirar y leer explican un recurso inexistente

### `backend/src/modules/directorio/application/zone-changed-handler.spec.ts`

- la cola retira solo los servicios de la zona anterior y repetir el evento no los cambia
- rechaza un evento sin la zona anterior antes de modificar servicios

### `backend/test/integration/directory.int-spec.ts`

- lista categorías sembradas con id estable, ícono y utilidad en emergencia
- guarda y actualiza el perfil propio, exige nivel 1 y zona y repite la cabecera
- publica 201 o 200 con el mismo id propio y guarda un solo evento
- guarda la ubicación exacta privada y solo publica la copia redondeada
- publica el punto exacto solo con aceptación y vuelve a redondear al editar sin ella
- edita solo el dueño, incrementa versión y explica un conflicto con ambas versiones
- retira con 204 aunque ya esté retirado y nunca resucita por reintentar la publicación
- omite servicios ocultos y rechaza perfiles ocultos o eliminados
- reintentos concurrentes crean un solo servicio y un id ajeno tiene un único ganador
- dos ediciones con versión 1 tienen un solo ganador y dos retiros terminan en 204
- un fallo del outbox revierte el INSERT y permite reintentar la misma clave
- el evento de zona retira solo lo anterior y su reintento conserva los servicios nuevos
- siembra servicios de demostración con copia pública aproximada
- exige sesión e Idempotency-Key en cada escritura y sesión en los perfiles
- valida UUIDv7, límites, atributos UTF-8, campos extra y categorías inexistentes

### `backend/test/integration/directory-migrations.int-spec.ts`

- publica solo sus tres tablas y concede lectura cuando powersync_rol existe
- revierte y aplica sin dejar tablas ni entradas de publicación y vuelve a sembrar categorías

Total: 42 casos nuevos escritos, sin ejecutar. Se mantienen también las pruebas existentes.
