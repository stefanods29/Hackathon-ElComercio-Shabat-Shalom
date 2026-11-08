# Fase 2 · Emergencias con operación

El objetivo es que, en una zona con cobertura operativa, un vecino pueda pedir ayuda aunque no
tenga señal, ver en qué estado está su pedido y saber qué hacer mientras tanto. Del otro lado,
coordinadores y brigadistas atienden los pedidos con tiempos acordados, desde la app y desde una
consola web, con los datos sensibles protegidos (secciones 7, 8 y 9). La fase empieza cuando la
Fase 1 cumple sus [criterios de salida](../fase-1/criterios-de-salida.md) y termina con los
[criterios de esta fase](criterios-de-salida.md).

## Estado

| Carpeta | Qué es | Dificultad | Responsable | Estado |
|---|---|---|---|---|
| [`lote-a-pedidos-offline-y-modo-operativo/`](lote-a-pedidos-offline-y-modo-operativo/) | Pedidos de ayuda sin conexión, streams por asignación, modo operativo protegido, tablero offline, seguridad e integración | ★★★★ | Stefano | Pendiente (0 de 6 partes) |
| [`lote-b-modulo-emergencias/`](lote-b-modulo-emergencias/) | Eventos, pedidos con estados, asignaciones, escalamiento, recursos críticos, roles y auditoría | ★★★ | Por asignar | Pendiente (0 de 5 partes) |
| [`lote-c-consola-web-y-avisos-urgentes/`](lote-c-consola-web-y-avisos-urgentes/) | Consola web de operación y avisos urgentes con SMS de respaldo | ★★ | stefanods29 | En curso; código en rama propia, sin validación |
| [`lote-d-tablero-de-emergencia/`](lote-d-tablero-de-emergencia/) | Tablero de emergencia, "Necesito ayuda", "Puedo ayudar", recursos y contactos | ★ | stefanods29 | En curso; código en rama propia, sin validación |

El estado de cada parte está en la tabla "Estado del lote" de cada guía.

## Antes de abrir la fase

Estas tres cosas no son de código, pero sin ellas la fase no puede salir:

1. **Aliados y roles operativos** (decisión 13.3.2): quién coordina, quién atiende y con qué
   acuerdos firmados.
2. **Tiempos de respuesta y caducidades definitivos** (decisión 13.3.6), acordados con los
   aliados. Los de la sección 9.2 son solo un ejemplo.
3. **Evaluación de impacto en la privacidad** antes de activar el tablero humanitario (sección 10).

## Cómo contribuir

Igual que en la [Fase 1](../fase-1/README.md#cómo-contribuir), con ramas
`f2-lote-<letra>/parte-<n>-<tema>`.

## Reglas para todos los lotes

Además de las de las fases anteriores:

1. **Los datos sensibles nunca viajan de forma masiva** (sección 8.1). El público ve solo
   agregados anónimos por celda. El detalle llega al coordinador y al brigadista asignados, bajo
   demanda.
2. **Minimización:** el brigadista ve la ubicación aproximada al aceptar el caso y la exacta solo
   cuando pasa a *en camino*.
3. **Todo acceso a un dato sensible queda auditado** (quién, cuándo y qué caso).
4. **Ningún aviso lleva datos sensibles en su texto**, porque se ve con la pantalla bloqueada.
5. **La app no promete lo que nadie garantiza:** muestra el estado real de cada pedido y siempre
   ofrece las alternativas oficiales (116, 105 y 106).

## Documentos de la Fase 2

| Documento | Para qué sirve |
|---|---|
| [`plan-de-lotes.md`](plan-de-lotes.md) | Los 4 lotes, cómo encajan y los hitos |
| [`criterios-de-salida.md`](criterios-de-salida.md) | Cuándo hay cobertura operativa real |
| [`evidencias/`](evidencias/) | Resultados del simulacro y de las pruebas de seguridad |
