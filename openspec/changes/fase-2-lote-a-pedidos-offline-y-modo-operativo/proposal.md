# Proposal

## Why

Un vecino puede necesitar ayuda cuando pierde la señal. La app debe conservar su pedido, decir con claridad si alguien lo recibió y proteger la información que queda en el celular. El Lote A de la Fase 2 desarrolla el flujo sin conexión, la sincronización y la protección local de las secciones 7.2–7.4 y 8 de la arquitectura, y verifica su encaje en la operación de la sección 9.

## What Changes

- Guardar pedidos de ayuda sin conexión con UUIDv7 y reintentos idempotentes. Mostrar el estado real, las alternativas oficiales y el historial propio, incluido el motivo de un cierre o una derivación al reconectar.
- Entregar datos de casos operativos solo a personal con asignación activa. Separar la ubicación aproximada de la exacta, auditar el acceso y retirar los datos al revocar la asignación.
- Proteger el modo operativo con PIN o biometría, bloqueo por inactividad, protección de pantallas y caducidad local.
- Sincronizar recursos críticos y agregados anónimos por zona para consultarlos sin conexión, con indicadores de antigüedad y prioridad sobre el tráfico ordinario.
- Verificar el aislamiento y la purga de datos, probar condiciones de campo e integrar el flujo con B, C y D para el simulacro.

El primer incremento de la Parte 1 se prueba con pedidos ficticios y un transporte controlado. La integración operativa de esa parte requiere el contrato aprobado de B y el puerto de las pantallas de D. Las Partes 2–6 siguen en el alcance de la Fase 2, con sus propias dependencias y verificaciones. La malla entre celulares y la escala de ciudad corresponden a la Fase 3.

## Capabilities

### New Capabilities

- `emergencias/pedidos-offline` — Creación persistente de pedidos, confirmación de recepción y consulta de estados propios sin exponer datos ajenos.
- `emergencias/tablero-offline` — Consulta de agregados anónimos y recursos críticos descargados, con indicación de su frescura.
- `app/modo-operativo-protegido` — Desbloqueo, bloqueo por inactividad y protección de las vistas operativas.

### Modified Capabilities

- `sincronizacion/datos-sensibles-bajo-demanda` — Distinguir la vista operativa asignada del historial propio, separar la ubicación exacta y auditar las aperturas.
- `app/almacenamiento-local-cifrado` — Aplicar la purga a los datos operativos reales y conservar para el autor únicamente el historial propio permitido.

## Impact

- Flutter reutiliza `app/lib/core/sync/` y la base cifrada por cuenta. El repositorio de Emergencias se conecta al puerto de D cuando su entrega esté disponible en la base acordada.
- PowerSync incorpora los streams del pedido propio, del caso asignado y del tablero. B conserva la propiedad de las tablas, los roles, la máquina de estados y las rutas de `contracts/openapi.yaml`. C aporta la consola, los avisos urgentes y la publicación del directorio.
- Android e iOS requieren comprobaciones en dispositivos reales. La apertura y la activación operativa dependen del cierre de la Fase 1, los acuerdos con los aliados, los plazos acordados y la evaluación de impacto en la privacidad.
