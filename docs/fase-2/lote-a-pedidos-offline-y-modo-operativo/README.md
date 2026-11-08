# Lote A · Pedidos offline y modo operativo (Fase 2)

| Dato | Valor |
|---|---|
| Dificultad | ★★★★ Alta (datos sensibles en el celular; integra la fase) |
| Área | `infra/powersync/sync-config.yaml`, `app/lib/core/sync/`, `app/lib/core/security/` (nuevo), `app/lib/features/emergencias/`, configuración nativa de `app/android` y `app/ios` |
| Change de OpenSpec | [`fase-2-lote-a-pedidos-offline-y-modo-operativo`](../../../openspec/changes/fase-2-lote-a-pedidos-offline-y-modo-operativo/) |
| Partes | 6. La 1 y la 3 pueden empezar con dobles; la 2 y la 4 necesitan las tablas de B |
| Depende de | Tablas y máquina de estados de B (partes 1–4) y pantallas de D |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Pedidos de ayuda sin conexión | En curso: conectada a B y D; faltan aprobar el contrato (1.4) y el modo avión en las pantallas (1.5) | `JDiazD33` | — |
| 2 | Streams bajo demanda por asignación | Hecha: PowerSync real con dos cuentas, purga local y CI ([evidencia](../evidencias/powersync-en-vivo.md)) | `JDiazD33` | — |
| 3 | Modo operativo protegido | En curso: falta comprobar las capturas bloqueadas en Android (3.2); el iPhone ya ocultó el caso | `JDiazD33` | — |
| 4 | Tablero sin conexión: agregados y recursos | En curso: frescura con el límite del servidor probada con reloj; falta el modo avión (4.2) | `JDiazD33` | — |
| 5 | Seguridad y pruebas de campo | En curso: plan, pruebas automáticas y una corrección (PEN-01); faltan el recorrido manual y la prueba de campo en teléfonos ([evidencia](../evidencias/penetracion.md)) | `JDiazD33` | — |
| 6 | Integración de la Fase 2 y simulacro | En curso: lotes unidos en `main`; libreto del simulacro preparado, falta realizarlo con los aliados ([evidencia](../evidencias/simulacro.md)) | `JDiazD33` | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## 0. Antes de empezar

Valen las reglas de las fases anteriores y las [reglas comunes de esta fase](../README.md#reglas-para-todos-los-lotes).
Ya existen la base local cifrada, la cola de subida, la purga por caducidad y cierre de sesión y el
stream del caso asignado con su purga al reasignarlo (Fase 0, partes 2–4). Esta fase los extiende
a los pedidos de ayuda reales.

---

## Parte 1 · Pedidos de ayuda sin conexión

- El pedido se crea en el celular con un `id` UUIDv7 y entra a la cola de subida con su clave de
  idempotencia. Mientras no se envía, la app dice "Tu pedido **todavía no fue enviado**. Nadie lo
  ha recibido." y ofrece las alternativas de la sección 7.4 (pantalla de D).
- Stream `mi_pedido` (clase personal): quien pidió ayuda recibe su propio pedido y su historial de
  estados, nunca los de otros.
- Si el pedido se cerró o se derivó mientras el celular estaba sin conexión, la app lo muestra con
  el motivo al reconectar.

Pruebas: cola con 0 pérdidas y 0 duplicados (como la prueba de 500 operaciones de la Fase 0, ahora
con pedidos), estados con HTTP falso y conflicto de cierre sin conexión.

El [resultado de laboratorio](../evidencias/pedidos-offline-laboratorio.md) cubre la cola, la reconciliación y la purga con pedidos ficticios. Las tareas 1.4–1.6 siguen
pendientes de verificación con B, D y CI.

## Parte 2 · Streams bajo demanda por asignación

- El celular de un coordinador o brigadista abre el stream de un caso solo mientras le está
  asignado (sección 8.2). Al terminar la asignación, PowerSync borra las filas en la siguiente
  sincronización.
- **Minimización:** al aceptar el caso llega la ubicación aproximada; la exacta llega solo cuando
  el caso pasa a *en camino*, en un stream aparte que depende del estado.
- Cada apertura queda auditada en el backend (B, parte 5).

El [informe de la Parte 2](../evidencias/streams-por-asignacion.md) documenta las pruebas con
filas ficticias, la ruta auditada propuesta y las verificaciones pendientes con el backend de B y
PowerSync en vivo.

La [verificación en vivo](../evidencias/powersync-en-vivo.md) completa las tareas 2.1–2.4 con PowerSync 1.28.1, dos cuentas, aislamiento por sesión, revocación, purga local y CI. La reasignación durante en camino se comprueba con una mutación SQL aislada: la API no permite esa transición.

### Pedidos para B y D

- **B · Parte 1.** Acordar y publicar `emergencias.historial_pedidos.motivo_para_autor` para los
  cierres y las derivaciones. El motivo operativo y el usuario del historial quedan fuera de la
  proyección de PowerSync.
- **B · Parte 2.** Acordar la autorización auditada ligada a sesión, asignación y alcance. El
  informe de la Parte 2 especifica la ruta, los campos y la revocación propuestos.
- **D · Parte 1.** Conectar `operationalEmergencyFactoryProvider` al repositorio de pedidos de
  la cuenta. Entregar `exactLocation` y `lifeThreatening` desde la pantalla de pedido, y presentar
  el resumen cuando la descripción y las coordenadas ya se retiraron de la cola.

## Parte 3 · Modo operativo protegido

- `core/security/`: bloqueo del modo operativo con PIN o biometría (`local_auth`) y cierre
  automático por inactividad.
- Capturas de pantalla bloqueadas en las pantallas sensibles en Android (`FLAG_SECURE`) y vista
  difuminada en el selector de apps de iOS.
- Caducidad local de los datos sensibles (por ejemplo, 24 horas o al cerrar el caso), aunque el
  celular siga sin conexión, sobre la purga de la Fase 0.

El [informe de la Parte 3](../evidencias/modo-operativo.md) describe el bloqueo local, la
caducidad y las pruebas de laboratorio. Las comprobaciones de captura y selector de apps en
teléfonos reales corresponden a la Parte 5.

## Parte 4 · Tablero sin conexión: agregados y recursos

- Stream público de agregados anónimos por celda ("3 pedidos de agua en esta zona"), que calcula
  B. Una celda con menos de 3 pedidos no se muestra, para que nadie pueda ser identificado.
- Recursos críticos con "reportado hace X" y la marca de posiblemente desactualizados según el
  umbral de su tipo (sección 7.3).
- En modo emergencia, la sincronización prioriza los datos críticos y desactiva las imágenes
  (ahorro de datos).

El [informe de la Parte 4](../evidencias/tablero-offline.md) documenta el SQL de B verificado
en PostgreSQL, el tablero local con datos descargados y la pausa de fotos. La conexión con
las pantallas de D y la fecha oficial de verificación dependen del acuerdo de integración.

## Parte 5 · Seguridad y pruebas de campo

- Prueba de penetración de los datos sensibles con OWASP MASVS (app) y OWASP API Security Top 10
  (backend), interna o con un tercero.
- Prueba técnica de emergencia: muchos celulares reconectándose a la vez, señal débil y batería
  baja, con pedidos sin conexión.

Evidencias: `penetracion.md` y `modo-operativo.md`.

## Parte 6 · Integración de la Fase 2 y simulacro

- Integrar en `main` las entregas aprobadas de B, C y D.
- Preparar y correr con los aliados un simulacro en la zona piloto: pedidos de cada prioridad,
  algunos creados sin señal, escalamiento por tiempos, avisos urgentes y cierre del evento.
- Con todo el equipo, hacer la revisión sin culpables (sección 9.6), comprobar el CI en verde y
  archivar los changes.

---

## Fuera de alcance

Malla entre celulares (I+D, Fase 3) y sincronización a escala de ciudad (Fase 3).

## Definición de terminado del lote

Las 6 partes aprobadas e integradas, el simulacro hecho y los criterios de salida con evidencia.
