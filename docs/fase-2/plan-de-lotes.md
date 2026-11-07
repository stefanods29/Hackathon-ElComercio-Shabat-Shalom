# Plan de lotes · Fase 2 (emergencias con operación)

**Entra** cuando la Fase 1 cumple sus criterios de salida y están listas las tres condiciones del
[README](README.md#antes-de-abrir-la-fase). **Sale** con cobertura operativa en la zona y un
simulacro con los aliados ([criterios](criterios-de-salida.md)).

## Los 4 lotes

| Lote | Partes | Qué entrega |
|---|---|---|
| **A · Pedidos offline y modo operativo** ★★★★ | 6 | Pedidos de ayuda sin conexión con estados, streams bajo demanda por asignación, bloqueo con PIN o biometría, caducidad local, tablero offline, seguridad e integración |
| **B · Módulo Emergencias** ★★★ | 5 | Eventos y activación, máquina de estados de los pedidos, asignaciones con escalamiento por tiempos, recursos críticos, roles operativos y auditoría |
| **C · Consola web y avisos urgentes** ★★ | 4 | Consola web de operación (cola, asignación, mapa de celdas, turnos, curaduría) y avisos urgentes con SMS de respaldo |
| **D · Tablero de emergencia** ★ | 4 | Inicio en modo emergencia, "Necesito ayuda" en 3 toques, "Puedo ayudar", recursos con frescura y contactos de emergencia |

## Cómo encajan

| Punto de contacto | Quién lo define | Quién lo usa | Mientras tanto |
|---|---|---|---|
| Rutas de Emergencias en `contracts/openapi.yaml` y máquina de estados (sección 7.2) | B (partes 1–2, primero el contrato) | A, C y D | D y C trabajan con dobles |
| Streams del pedido propio, del caso asignado y de los agregados por celda | A (partes 1, 2 y 4) con las tablas de B | D (pantallas) y C (mapa de celdas) | Datos sembrados |
| Eventos `emergencias.*` del outbox | B | C (avisos y consola) y A (purga al cerrar casos) | — |
| Plantillas de aviso sin datos sensibles | C (parte 4) | B (escalamiento) | Registro en consola |
| Directorio de emergencia publicado desde la consola | C (parte 3) con el esquema de la Fase 1 | A y D | Archivo por PR, como en la Fase 1 |

## Hitos

| Hito | Se cumple cuando… |
|---|---|
| **H1 · Contratos** | Contrato y máquina de estados de B1–B2 aprobados; ADR de la consola (C1) aprobado |
| **H2 · Pedido de punta a punta** | A1–A2, B1–B3, C2 y D1–D2 aprobadas: un pedido creado sin señal llega a un coordinador, se asigna y cambia de estado en el celular de quien pidió |
| **H3 · Operación completa** | A3–A4, B4–B5, C3–C4 y D3–D4 aprobadas; prueba de penetración hecha |
| **H4 · Salida de la Fase 2** | A5 y A6 aprobadas, simulacro con los aliados y criterios con evidencia |

## Changes de OpenSpec (se crean al abrir la fase)

| Lote | Change |
|---|---|
| A | `fase-2-lote-a-pedidos-offline-y-modo-operativo` |
| B | `fase-2-lote-b-modulo-emergencias` |
| C | `fase-2-lote-c-consola-web-y-avisos-urgentes` |
| D | `fase-2-lote-d-tablero-de-emergencia` |
