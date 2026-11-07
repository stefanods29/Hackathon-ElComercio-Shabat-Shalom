# Criterios de salida de la Fase 0

La Fase 0 termina cuando cada supuesto de la sección 13.1 tiene evidencia. Cada fila indica qué
lote y qué tarea la produce, y dónde queda la evidencia.

El 7 de noviembre de 2026 el usuario autorizó omitir las pruebas de campo en iPhone
porque solo dispone de un Redmi. Se registran como omitidas; las comprobaciones de
compilación de iOS en CI se mantienen. La matriz adversa de Android continúa pendiente.

| Supuesto (13.1) | Criterio de aceptación | Lote · tarea | Evidencia | Estado |
|---|---|---|---|---|
| La cola offline no pierde ni duplica envíos | 0 pérdidas y 0 duplicados en 500 operaciones (modo avión, señal débil, cierre forzado, reinicio, batería baja) en Android de gama baja e iPhone | A · 5.1 | `evidencias/cola-offline.md` | ☐ |
| La sincronización en segundo plano es oportunista | Comportamiento medido y documentado; la UI no promete inmediatez | A · 5.2 | `evidencias/segundo-plano.md` | ☐ |
| Los rechazos y conflictos se entienden | Dos vecinos toman el mismo favor sin conexión: el segundo ve el motivo y una alternativa | A · 5.3 + D · 3.3 | `evidencias/conflicto.md` | ☐ |
| Los datos sensibles solo llegan a quien corresponde | 0 filas sensibles en dispositivos no autorizados (pruebas de los streams) | A · 4.3 | Pruebas automatizadas + `evidencias/datos-sensibles.md` | ☐ |
| La purga funciona | Datos borrados al reconectar, al vencer la caducidad y al cerrar sesión | A · 2.2–2.4 y 5.4 | `evidencias/purga.md` | ☐ |
| La capacidad en un pico de emergencia | p95 y tasa de error dentro de lo acordado; la cola crítica no se degrada | B · 6.1–6.3 | `evidencias/capacidad.md` | ☐ |
| Los mapas offline son viables y están permitidos | Términos que permiten el uso offline; tamaño aceptable en gama baja | C · 1.1 y 2.2–2.3 | ADR de teselas + `evidencias/mapas.md` | ☐ |
| Avisos por token y por tópico | Llega un aviso personal y uno de zona, sin datos sensibles en el texto | C · 4.4 | `evidencias/avisos.md` | ☐ |
| El stack es compatible entre sí | Compila, sincroniza y se despliega en Android e iOS | Cimientos 3.3 + A · 6.2 | CI en verde en `main` | ☐ |
