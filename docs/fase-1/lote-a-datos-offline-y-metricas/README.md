# Lote A · Datos offline y métricas (Fase 1)

| Dato | Valor |
|---|---|
| Dificultad | ★★★★ Alta (el más complejo de la fase; integra a los demás) |
| Área | `infra/powersync/sync-config.yaml`, `app/lib/core/sync/`, `app/lib/features/emergencias/`, `backend/src/shared/observability/`, `contracts/`, `infra/cdn/publico/emergencia/` |
| Change de OpenSpec | `openspec/changes/fase-1-lote-a-datos-offline-y-metricas/` (proposal, design, specs, tasks) |
| Partes | 6. La 1, la 2 y la 3 pueden avanzar en paralelo; la 5 y la 6 cierran la fase |
| Depende de | Contratos de B (partes 1–5), Media de C (parte 1) y staging de C (parte 4) |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Datos públicos del piloto en el celular | En curso: implementada y verificada en local; falta aprobar el ADR 0010 y la CI | JDiazD33 | Rama `f1-lote-a/parte-1-datos-publicos` |
| 2 | Directorio de emergencia sin conexión | En curso: implementada; pruebas de la app escritas sin ejecutar; falta la prueba en un celular en modo avión y la CI | JDiazD33 | Rama `f1-lote-a/parte-2-directorio-emergencia` |
| 3 | Métricas de sincronización | En curso: implementada; pruebas escritas sin ejecutar; falta `npm run verify`, `npm run test:integration`, `tool/verify.sh`, Redocly y la CI | JDiazD33 | Rama `f1-lote-a/parte-3-metricas` |
| 4 | Zona, cuenta y fotos pendientes | En curso: implementada; pruebas escritas sin ejecutar; falta la prueba en celulares reales (4.5) y la CI | JDiazD33 | Rama `f1-lote-a/parte-4-zona-y-cuenta` |
| 5 | Piloto en campo | Pendiente | JDiazD33 | — |
| 6 | Integración de la Fase 1 | Pendiente | JDiazD33 | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## 0. Antes de empezar

### 0.1 Reglas

Las de la Fase 0 ([`../../fase-0/lote-a-nucleo-offline/README.md`](../../fase-0/lote-a-nucleo-offline/README.md))
y las [reglas comunes de la fase](../README.md#reglas-para-todos-los-lotes). La UI solo lee de la
base local y la red solo la actualiza: ninguna pantalla nueva llama a la API para mostrar datos.

### 0.2 Lo que ya existe

- PowerSync con Sync Streams (`infra/powersync/sync-config.yaml`), base local cifrada, cola de
  subida con `Idempotency-Key`, purga por caducidad y cierre de sesión, y el stream del caso
  asignado (Fase 0, partes 1–4).
- Repositorio del muro sobre PowerSync (`powersync_post_repository.dart`) y conector de subida
  (`core/sync/vecinal_connector.dart`): es el patrón para los repositorios nuevos.
- Métricas operativas del backend en `GET /v1/operacion/metricas` (Lote B de la Fase 0).
- La [revisión del 7 de noviembre](../../fase-0/revision-2026-11-07.md) dejó dos temas para esta
  fase: la precisión de la ubicación pública y el acceso al nivel 1.

---

## Parte 1 · Datos públicos del piloto en el celular

**Qué entrega:** el directorio y las reseñas de la zona llegan al celular y se pueden consultar sin
señal, sin exponer la ubicación exacta de nadie.

Qué construir:

- **ADR 0010 · Precisión de la ubicación en los datos públicos.** Propuesta: redondear a 3
  decimales (unos 110 m) la ubicación de publicaciones y servicios. Un proveedor con local a la
  calle puede elegir mostrar su dirección exacta, con un consentimiento explícito. La API guarda la
  copia pública (lo implementa B) y los streams solo publican esa copia. También se aplica al muro
  existente, con una migración de los datos sembrados.
- **Streams nuevos:** `categorias` (globales); `servicios_de_mi_zona` (solo columnas públicas, sin
  borrados ni ocultos); `resenas_publicadas` de esos servicios con sus fotos; `mis_resenas` (todas
  las mías, en cualquier estado) y `mis_vistos_buenos`.
- **App:** tablas en `core/sync/local_schema.dart` y repositorios sobre PowerSync para el
  directorio y la reputación. Reemplazan a los repositorios en memoria del Lote D sobreescribiendo
  sus proveedores de Riverpod. El conector de subida aprende las operaciones nuevas (servicio,
  reseña, Visto Bueno, denuncia) y las envía a las rutas de B con la clave de idempotencia del
  registro local.

Cómo se prueba:

- `npm run sync:validate` y pruebas de acceso de los streams: un vecino de otra zona no recibe
  filas; una reseña *en revisión* solo llega a su autor; lo que se oculta desaparece del celular en
  la siguiente sincronización.
- Prueba de la app con PowerSync real: el directorio se abre en modo avión con
  "Actualizado hace X".

**Terminado cuando:** ADR aprobado, streams y repositorios integrados, y ninguna columna pública
lleva la ubicación exacta de una persona.

## Parte 2 · Directorio de emergencia sin conexión

**Qué entrega:** números oficiales, puntos de encuentro, centros de salud y albergues disponibles
siempre, con su fuente y su fecha de verificación (sección 7.3).

Qué construir:

- **Contrato:** `contracts/directorio-emergencia.schema.json` (JSON Schema). Tiene `version`,
  `distrito`, `generadoEn` y `entradas`. Cada entrada lleva `id`, `tipo` (`numero`,
  `punto_de_encuentro`, `centro_de_salud` o `albergue`), `nombre`, `telefono` o la ubicación según
  el tipo, `fuente` y `verificadoEn`.
- **Publicación:** un JSON por distrito en `infra/cdn/publico/emergencia/` más un `indice.json`
  con la versión y el hash de cada archivo. En esta fase el curador lo actualiza con un PR; la
  consola web lo reemplaza en la Fase 2.
- **App:** `features/emergencias/data/`. La app descarga el archivo al iniciar sesión y luego de
  forma periódica (respetando el ahorro de datos), valida el esquema y el hash, y lo guarda en el
  celular. Trae además una copia de respaldo con los números 116, 105 y 106 y su fecha. Pasado el
  umbral configurado, marca los datos como posiblemente desactualizados.

Cómo se prueba: unitarias de lectura, validación y antigüedad; prueba de widget que lo abre sin red
y solo con la copia de respaldo; prueba en un celular en modo avión.

**Terminado cuando:** el Lote D puede mostrarlo sin señal y cada dato muestra su fuente y su fecha.

## Parte 3 · Métricas de sincronización

**Qué entrega:** saber si la sincronización está sana durante el piloto (sección 11).

Qué construir:

- Contadores en la app: tamaño de la cola local, tiempo desde "Guardado en tu celular" hasta
  "Enviado" (p50 y p95), rechazos permanentes por código, tiempo desde la última sincronización y
  errores de conexión.
- Envío agregado y anónimo, con solo la versión de la app y el sistema, a
  `POST /v1/telemetria/sincronizacion`, con `@Idempotent()`. Va en `shared/observability`, junto a
  las métricas operativas. El esquema Zod rechaza campos que no estén en el contrato.
- La ruta se agrega al contrato y las métricas se exportan por OpenTelemetry para el tablero del
  Lote C (parte 5).

Cómo se prueba: unitarias de la agregación; integración de la ruta (guarda contadores y rechaza
campos extra); revisión de que ningún campo identifica a una persona.

**Terminado cuando:** el tablero de C muestra las métricas de un celular de prueba.

## Parte 4 · Zona, cuenta y fotos pendientes

**Qué entrega:** cambiar de zona o borrar la cuenta deja el celular limpio.

Qué construir:

- **Cambio de zona** (ruta de B, parte 4): la app reconecta los streams de la zona nueva y
  comprueba que los datos de la anterior se borran.
- **Borrar la cuenta** (derecho de cancelación, B parte 4): borra la base local, los archivos, el
  almacenamiento seguro y el token de avisos.
- **Fotos pendientes** (cola de C, parte 2): al cerrar sesión o borrar la cuenta se eliminan sin
  subirse.
- Si la tarea 2.5 de la Fase 0 sigue abierta, la baja del token de avisos se termina aquí.

Cómo se prueba: unitarias y de integración con HTTP falso para cada caso, y una prueba en un
celular real.

**Terminado cuando:** los tres casos se comprueban en Android y en iOS (o con la excepción
autorizada para iPhone).

## Parte 5 · Piloto en campo

**Qué entrega:** la evidencia de los criterios de salida.

Qué hacer:

- Preparar el piloto con todo el equipo: barrio y flujos elegidos (decisión 13.3.1), material de
  consentimiento, instalación por las betas del Lote C (parte 4) y un canal de soporte.
- Durante al menos 4 semanas, revisar cada semana las métricas (parte 3 y tablero de C), la cola
  de moderación (B parte 5) y los incidentes.
- Completar con los celulares del piloto lo que la Fase 0 dejó pendiente al cerrarse
  ([criterios de salida](../../fase-0/criterios-de-salida.md)):
  - La matriz adversa de la cola: señal débil, cierre forzado, reinicio y batería baja (A 5.1).
  - La sincronización en segundo plano, medida y documentada (A 5.2).
  - El conflicto con dos celulares sin conexión (A 5.3).
  - El mapa sin conexión: tamaño de la región en un Android de gama baja y prueba en modo avión
    (C 2.1–2.3).
  - Avisos por token y por tópico recibidos en el celular, con la cuenta de servicio de FCM
    (C 4.1–4.4).

**Terminado cuando:**
- `evidencias/piloto.md`, `sincronizacion.md`, `datos-publicos.md` y `directorio-emergencia.md`
  están completos y sin datos personales.
- `../fase-0/evidencias/cola-offline.md`, `conflicto.md`, `mapas.md` y `avisos.md` registran las
  pruebas de campo pendientes.

## Parte 6 · Integración de la Fase 1

- Integrar en `main` las entregas aprobadas de B, C y D.
- Probar el flujo completo: registro → consentimiento → confirmación de residencia → búsqueda de
  un servicio sin señal → reseña con foto guardada sin conexión y enviada después → denuncia → el
  moderador la oculta → desaparece en otro celular → directorio de emergencia en modo avión.
- Comprobar el CI en verde, desplegar en staging y luego en producción (con C), y archivar los
  changes de la fase.

---

## Puntos de contacto con otros lotes

- **B:** copia pública de la ubicación, rutas y eventos de cada módulo, y la ruta de telemetría en
  el contrato.
- **C:** URLs de archivos y cola de fotos, CDN del directorio de emergencia, staging y tableros.
- **D:** las pantallas leen solo de los repositorios de este lote.

## Fuera de alcance

Pedidos de ayuda y tablero humanitario (Fase 2), modo operativo con PIN (Fase 2) y sincronización
a escala (Fase 3).

## Definición de terminado del lote

Las 6 partes aprobadas e integradas, los criterios de salida con evidencia y los cuatro changes de
la fase archivados.
