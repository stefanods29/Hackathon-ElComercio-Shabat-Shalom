# Criterios de salida de la Fase 0

La Fase 0 termina cuando cada supuesto de la sección 13.1 tiene evidencia. Cada fila indica qué
lote y qué tarea la produce, y dónde queda la evidencia.

El 7 de noviembre de 2026 el usuario autorizó omitir las pruebas de campo en iPhone
porque solo dispone de un Redmi. Se registran como omitidas; las comprobaciones de
compilación de iOS en CI se mantienen. La matriz adversa de Android continúa pendiente.

Estado al 7 de noviembre de 2026 ([revisión](revision-2026-11-07.md)): ✓ cumplido ·
◐ parcial · ☐ sin evidencia.

| Supuesto (13.1) | Criterio de aceptación | Lote · tarea | Evidencia | Estado |
|---|---|---|---|---|
| La cola offline no pierde ni duplica envíos | 0 pérdidas y 0 duplicados en 500 operaciones (modo avión, señal débil, cierre forzado, reinicio, batería baja) en Android de gama baja e iPhone | A · 5.1 | `evidencias/cola-offline.md` | ◐ 500 envíos sintéticos sin pérdidas ni duplicados en Android; falta la matriz adversa |
| La sincronización en segundo plano es oportunista | Comportamiento medido y documentado; la UI no promete inmediatez | A · 5.2 | `evidencias/segundo-plano.md` | ☐ Sin medir |
| Los rechazos y conflictos se entienden | Dos vecinos toman el mismo favor sin conexión: el segundo ve el motivo y una alternativa | A · 5.3 + D · 3.3 | `evidencias/conflicto.md` | ☐ La pantalla existe (D 3.3); falta la prueba con dos celulares |
| Los datos sensibles solo llegan a quien corresponde | 0 filas sensibles en dispositivos no autorizados (pruebas de los streams) | A · 4.3 | Pruebas automatizadas + `evidencias/datos-sensibles.md` | ◐ Stream de casos restringido al personal asignado y comprobado en Android; falta `datos-sensibles.md` |
| La purga funciona | Datos borrados al reconectar, al vencer la caducidad y al cerrar sesión | A · 2.2–2.4 y 5.4 | `evidencias/purga.md` | ✓ En Android (iPhone omitido con autorización) |
| La capacidad en un pico de emergencia | p95 y tasa de error dentro de lo acordado; la cola crítica no se degrada | B · 6.1–6.3 | `evidencias/capacidad.md` | ◐ Escenario completo listo; solo corrió el humo local; falta staging |
| Los mapas offline son viables y están permitidos | Términos que permiten el uso offline; tamaño aceptable en gama baja | C · 1.1 y 2.2–2.3 | ADR de teselas + `evidencias/mapas.md` | ☐ Lote C sin empezar |
| Avisos por token y por tópico | Llega un aviso personal y uno de zona, sin datos sensibles en el texto | C · 4.4 | `evidencias/avisos.md` | ☐ Lote C sin empezar |
| El stack es compatible entre sí | Compila, sincroniza y se despliega en Android e iOS | Cimientos 3.3 + A · 6.2 | CI en verde en `main` | ◐ Compila en CI para Android e iOS y sincroniza en Android; falta desplegar |

La capacidad y el despliegue necesitan un entorno de staging, que el plan pone en la Fase 1
(Lote C, parte 4). El equipo decide si adelanta un staging mínimo para cerrar la Fase 0 o si
acepta estos dos criterios con lo medido en local y los cierra en staging al empezar la Fase 1.
