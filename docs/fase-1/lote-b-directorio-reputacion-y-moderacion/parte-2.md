# Parte 2 · Entrega para revisión

Rama: `f1-lote-b/parte-2-busqueda`. Base: `f1-lote-b/parte-1-directorio`,
`4aef0c3bd02af6c1e5a16527cfe47446ef210e4f`. Responsable: JDiazD33.

Código de las tareas 2.1–2.3 escrito y consulta de 2.4 preparada para el supervisor.
No se ejecutan las pruebas ni `EXPLAIN`. La tarea 2.5 y la validación de 2.4 quedan pendientes;
las casillas de OpenSpec siguen reservadas al supervisor y no se marcan.

## Cobertura por tarea

Rutas relativas a la raíz del repositorio.

| Tarea | Código o documento escrito | Pruebas escritas |
|---|---|---|
| 2.1 | `contracts/openapi.yaml`, primer commit `8cbaa0a`; `backend/src/modules/directorio/api/schemas.ts`, `api/directory.controller.ts` | `api/service-search-schema.spec.ts`: valores por defecto, booleanos y límites; `backend/test/integration/service-search.int-spec.ts`: sesión/zona y errores HTTP. Redocly pendiente |
| 2.2 | `backend/src/modules/directorio/infrastructure/migrations/202611080110_directorio_busqueda.ts`, `infrastructure/tables.ts`, `service-search.query.ts`, `service-search.reader.kysely.ts`; `application/search-ports.ts`, `find-services.ts`, `service-cursor.ts`; `directory.module.ts` | `application/find-services.spec.ts`, `application/service-cursor.spec.ts`; `backend/test/integration/service-search.int-spec.ts` (cercanía, zona, categoría, emergencia, tildes/errores, orden mixto, cursor con ancla retirada); `service-search-migrations.int-spec.ts` (inmutabilidad, columna generada, índices, reversión). Se ajusta `directory-migrations.int-spec.ts` para revertir en orden |
| 2.3 | `backend/src/modules/directorio/domain/distance.ts`, lector Kysely y proyección explícita de DTO | `domain/distance.spec.ts`: 437→450 y límites de los tramos; integración: copia pública, distancia, ausencia de escrituras y punto omitido del registro HTTP |
| 2.4 | `docs/fase-1/evidencias/busqueda.md`: consulta completa de `EXPLAIN`, predicado de segunda página y diagnósticos de índices | Preparada, sin ejecutar. El plan natural, tiempos y buffers reales deben registrarse después de la ejecución del supervisor |
| 2.5 | Sin ejecución por instrucción del encargo | Tipos, lint, pruebas, build, Redocly y CI pendientes del supervisor |

## Contrato

Se añade `GET /v1/servicios` con sesión y zona: `lat`, `lng`, `radioM` (100–20000, 2000 por
defecto), `categoriaId`, `q` (1–120), `soloEmergencia` (false por defecto), `cursor` y `limite`
(1–50, 20 por defecto). Responde `PaginaDeServicios` con `datos: ServicioCercano[]` y
`siguienteCursor`; cada servicio conserva el esquema `Servicio` de la Parte 1 y añade
`distanciaMetros`, entero múltiplo de 50. Respuestas 400 `validacion`, 401 de autenticación y
403 `sin_zona`. No exige nivel 1 ni `Idempotency-Key`, y no añade rutas de otras partes.

## Migración y PowerSync

`202611080110_directorio_busqueda.ts` agrega `directorio.sin_tildes(text)` `IMMUTABLE`, con
`public.unaccent` y diccionario explícito, y `servicios.busqueda` (`tsvector` generado `STORED`)
con configuración `spanish` y título/descripción. Crea `servicios_busqueda_gin`,
`servicios_titulo_trgm_gin` y `servicios_orden_idx` (zona, vistos buenos DESC, puntaje DESC, id ASC).
Reutiliza `servicios_ubicacion_gix` de la Parte 1. `down` retira esos índices, columna y función.

No se agregan tablas a `powersync` ni se cambian sus permisos: `directorio.servicios` ya está
publicada. La columna de búsqueda no se incluye en los DTO ni en los campos públicos acordados.
No hay variables nuevas ni cambios en `.env.example` o en el esquema de configuración.

## Decisiones y revisión prioritaria

- No cambian las tablas/columnas públicas, rutas ni eventos de las decisiones 1–3. El texto
  usa `@@ websearch_to_tsquery` o `%>` con umbral local 0,3, equivalente al criterio de
  `word_similarity > 0.3` del diseño; el operador hace elegible el índice de trigramas. La
  referencia técnica está enlazada en la evidencia. No se afirma que el planificador haya
  elegido un índice sin ejecutar la consulta.
- Revisar los tres casos del predicado de continuación: los dos contadores bajan y el id sube.
  El cursor transporta solo `v`, `p` e `id`, valida tipos/rangos/precisión y no incluye el punto.
  Sigue usable sin el ancla. Deben conservarse los filtros; como en el diseño, no guarda una
  instantánea si cambian los agregados entre páginas.
- Los servicios y proveedores deben estar vigentes y pertenecer a la misma zona certificada.
  La selección enumera únicamente columnas públicas; la ubicación privada solo se usa dentro
  de `ST_DWithin` y `ST_Distance` y no se proyecta al objeto de respuesta.
- La lectura usa una transacción para fijar localmente el umbral de trigramas. Revisar su
  restauración al devolver la conexión al pool. Hay una prueba escrita que parte de 0,9 y
  comprueba que se conserva después de buscar con 0,3.
- La envoltura `IMMUTABLE` presupone reglas fijas de `unaccent`. Cambiarlas requiere una
  migración que recalcule el tsvector y reconstruya el índice de expresiones.
- Los datos de integración usan ids, teléfonos y zonas propios de cada caso. Además se comprueba
  que el servicio de demostración de Beto aparezca para `gásfiter`. No se modifica la semilla.

## Verificación de esta entrega

Revisión por lectura del diff, comparación con diseño/specs, límites de rutas editadas y
`git diff --check`. Formato aplicado con el Prettier que ya estaba instalado, sin instalar
paquetes. No se ejecutan pruebas, linters, comprobaciones de tipos, builds, migraciones,
base de datos, API, workers, Redocly ni `EXPLAIN`. No se declara ninguna prueba aprobada.

El supervisor debe aplicar migraciones y semilla, ejecutar `npm run verify`,
`npm run test:integration`, Redocly y las consultas de la evidencia, y revisar CI.
Se conservan todos los changes de OpenSpec y las casillas sin cambios. No se tocan `app/`,
`infra/`, observabilidad ni otras áreas del equipo.

## Pruebas escritas (nombres exactos)

### `backend/src/modules/directorio/application/service-cursor.spec.ts`

- el cursor conserva solo vistos buenos, puntaje e id, sin coordenadas
- rechaza formato, tamaño y base64 no canónico
- rechaza cursores que no contienen exactamente las tres claves válidas

### `backend/src/modules/directorio/application/find-services.spec.ts`

- permite buscar desde nivel 0 y pasa los filtros y la zona certificada al puerto en memoria
- codifica el cursor de salida y decodifica el de entrada sin consultar el ancla
- exige zona y rechaza el cursor inválido antes de invocar el puerto

### `backend/src/modules/directorio/domain/distance.spec.ts`

- redondea 437 m a 450 m y nunca devuelve precisión menor a 50 m

### `backend/src/modules/directorio/api/service-search-schema.spec.ts`

- aplica radio, límite y emergencia por defecto sin confundir false con true
- valida rangos, tipos, límites, texto, categoría y campos desconocidos

### `backend/test/integration/service-search.int-spec.ts`

- exige sesión y zona, pero permite buscar desde nivel 0 sin clave de idempotencia
- encuentra el servicio sembrado de Gasfitería al buscar gásfiter
- filtra por radio y zona aunque otra zona tenga un servicio en el mismo punto
- combina categoría y disponibilidad en emergencia sin convertir false en true
- tolera tildes y errores de tipeo y busca en la descripción con configuración spanish
- ordena por vistos buenos, luego puntaje y después id con páginas sin repetidos ni saltos
- continúa con el mismo cursor aunque se retire el servicio que cerraba la página
- excluye servicios retirados u ocultos y perfiles ocultos, retirados o de otra zona
- devuelve 450 m para 437 m y solo la copia pública de la ubicación
- buscar no modifica servicios ni crea outbox o idempotencia y el registro HTTP omite el punto
- actualiza el tsvector generado cuando cambia el título o la descripción
- fija el umbral de trigramas solo durante la transacción y no contamina la conexión
- responde 400 ante filtros o cursores inválidos sin reflejar el punto en el problema

### `backend/test/integration/service-search-migrations.int-spec.ts`

- crea sin_tildes IMMUTABLE, el tsvector generado y los índices de texto y orden
- revierte y aplica sin perder servicios ni cambiar las tablas publicadas

Total: 24 pruebas nuevas declaradas, sin ejecutar; se mantiene la cobertura de la Parte 1.
