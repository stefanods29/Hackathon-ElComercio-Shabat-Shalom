# Lote B · Módulo Emergencias (Fase 2)

| Dato | Valor |
|---|---|
| Dificultad | ★★★ Media-alta |
| Área | `backend/src/modules/emergencias/`, `identidad/`, `notificaciones/`, `backend/src/workers/`, `contracts/openapi.yaml` |
| Change de OpenSpec | [`fase-2-lote-b-modulo-emergencias`](../../../openspec/changes/fase-2-lote-b-modulo-emergencias/) |
| Partes | 5. La 1 y la 2 van primero (contrato y máquina de estados) |
| Depende de | Plantillas de aviso de C (parte 4); los streams de A usan estas tablas |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Eventos y activación del modo emergencia | En curso: integrada en `main` y probada por la API; falta la CI | `Defartion` | — |
| 2 | Pedidos de ayuda y su máquina de estados | En curso: integrada en `main` y probada por la API; falta la CI | `Defartion` | — |
| 3 | Asignaciones, escalamiento y turnos | En curso: integrada en `main` y probada por la API; falta la CI | `Defartion` | — |
| 4 | Recursos críticos y reportes verificables | En curso: integrada en `main` y probada por la API; falta la CI | `Defartion` | — |
| 5 | Roles operativos, auditoría y cierre del evento | En curso: integrada y probada por la API; faltan la CI y revisar las migraciones | `Defartion` | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

La rama `f2-lote-b/modulo-emergencias` se escribió sin compilar ni probar. La integración en
`main` la dejó compilando y la probó por la API con PostgreSQL (hito H2), además de agregar lo que
necesitaban los streams de A ([integración](../integracion.md)). Configuración, alcance y
conexiones con A/C/D en [entrega.md](entrega.md). No se habilitó una operación real.

---

## 0. Antes de empezar

Valen las reglas de las fases anteriores y las [reglas comunes de esta fase](../README.md#reglas-para-todos-los-lotes).
El esquema `emergencias` es **restringido**: ningún otro módulo lee sus tablas, y la ubicación
exacta y los datos de salud van en columnas a las que solo llegan los roles asignados. El patrón
State (sección 4.3) es obligatorio para los pedidos.

---

## Parte 1 · Eventos y activación del modo emergencia

- `emergencias.eventos`: zona o polígono, nivel, estado (`normal`, `emergencia` o
  `recuperacion`), quién lo activó y cuándo.
- Activación manual por coordinadores de la zona (`POST /v1/zonas/{id}/eventos`, `@Idempotent()`)
  y automática a partir de alertas oficiales detrás de un puerto (`OfficialAlertSource`), con un
  adaptador por fuente cuando haya canal de datos (IGP, SENAMHI o INDECI), reintentos y circuit
  breaker.
- **Regla de cobertura** (sección 9.3): sin 2 coordinadores activos y un turno, la zona no habilita
  pedidos (409 `zona_sin_cobertura`) y la app muestra el directorio de emergencia.
- Al activarse, el evento `emergencias.evento_activado` dispara el aviso público de zona (C).

## Parte 2 · Pedidos de ayuda y su máquina de estados

- `emergencias.pedidos_ayuda`: estado, prioridad, tipo de necesidad, celda pública, ubicación
  exacta restringida, `caduca_en` y `version`. `historial_pedidos` guarda cada transición con hora
  y rol.
- Solo las transiciones de la sección 7.2: *enviado → visto → en camino → atendido*, más
  *derivado* y *cerrado sin atender*, ambas con motivo. Cualquier otra responde 409
  `transicion_invalida`.
- `POST /v1/pedidos-ayuda` (`@Idempotent()`, con el `id` del celular; nivel 0, porque en una
  emergencia nadie queda fuera) y las rutas de cada transición por rol.

Pruebas: tabla de transiciones completa (válidas e inválidas), reintentos idempotentes y acceso por
rol.

## Parte 3 · Asignaciones, escalamiento y turnos

- `asignaciones`, `turnos` y `grupos_apoyo` (verificados).
- Escalamiento con trabajos programados de pg-boss: si un pedido sigue *enviado* sin revisar pasado
  el tiempo de su prioridad, escala al siguiente coordinador o a la zona vecina, y quien pidió
  ayuda recibe las alternativas oficiales. Los tiempos son configurables (sección 9.2).
- Aviso personal al coordinador o brigadista, siempre con un texto genérico.

Pruebas: con reloj de prueba, cada prioridad escala a tiempo y un reintento del trabajo no escala
dos veces.

## Parte 4 · Recursos críticos y reportes verificables

- `recursos_criticos`: tipo, cantidad, `reportado_en` y umbral de antigüedad por tipo (por ejemplo,
  2 horas para el agua y 30 días para un punto de encuentro).
- Estados de un reporte (sección 7.6): *sin verificar → confirmado por N vecinos → verificado por
  un coordinador*. Las fuentes oficiales llevan insignia.
- Worker de agregados anónimos por celda para el stream público de A (umbral mínimo de 3).

## Parte 5 · Roles operativos, auditoría y cierre del evento

- Roles `coordinador`, `brigadista` y `curador` con sus requisitos (sección 9.1): nivel 3 (validación
  de DNI con revisión humana y sin guardar imágenes del documento más tiempo del necesario),
  capacitación y acuerdo de confidencialidad registrados.
- Auditoría de cada acceso a un dato sensible: quién, cuándo y qué caso, consultable por el
  administrador.
- Cierre del evento: los casos se cierran y se anonimizan (sección 9.6) con un trabajo, y se
  exportan las cifras para la revisión sin culpables.

Pruebas: permisos de cada rol, auditoría de cada acceso y anonimización comprobada en la base de
datos.

---

## Fuera de alcance

Consola web (Lote C), SMS de respaldo (Lote C), Valkey y extracción del módulo como servicio
(Fase 3).

## Definición de terminado del lote

Las 5 partes aprobadas e integradas, el contrato y la máquina de estados documentados en OpenSpec,
el grafo actualizado y las pruebas de acceso por rol en verde.
