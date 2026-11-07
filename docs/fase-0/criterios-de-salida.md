# Criterios de salida de la Fase 0

La Fase 0 termina cuando cada supuesto de la sección 13.1 tiene evidencia. Cada fila indica qué
lote y qué tarea la produce, y dónde queda la evidencia.

El 7 de noviembre de 2026 el usuario autorizó omitir las pruebas de campo en iPhone
porque solo dispone de un Redmi. Se registran como omitidas; las comprobaciones de
compilación de iOS en CI se mantienen.

## Cierre del 7 de noviembre de 2026

El usuario cerró la Fase 0 con el código de los cuatro lotes integrado y la evidencia de esta
tabla. Lo que todavía requiere varios celulares, semanas de uso o un entorno de staging pasa al
piloto de la Fase 1, con autorización del usuario:
- Pruebas en dispositivo: [Lote A, parte 5](../fase-1/lote-a-datos-offline-y-metricas/README.md#parte-5--piloto-en-campo).
- Staging: [Lote C, parte 4](../fase-1/lote-c-fotos-entornos-y-observabilidad/README.md).

Estos pendientes se aceptan como riesgos conocidos y no bloquean el inicio de la Fase 1.

Leyenda: ✓ cumplido · ✓\* cumplido con el alcance que aprobó el usuario · ◐ parcial ·
→ lo que se completa en la Fase 1.

| Supuesto (13.1) | Criterio de aceptación | Lote · tarea | Evidencia | Estado |
|---|---|---|---|---|
| La cola offline no pierde ni duplica envíos | 0 pérdidas y 0 duplicados en 500 operaciones | A · 5.1 | `evidencias/cola-offline.md` | ✓\* 500 de 500 envíos desde el Redmi, sin pérdidas ni duplicados. → La matriz adversa (señal débil, reinicio, batería baja) se corre con los celulares del piloto |
| La sincronización en segundo plano es oportunista | Comportamiento medido y documentado; la UI no promete inmediatez | A · 5.2 | `../fase-1/evidencias/sincronizacion.md` | → La UI ya muestra «Guardado en tu celular» hasta confirmar el envío; la medición se hace en el piloto |
| Los rechazos y conflictos se entienden | Si dos vecinos toman el mismo favor, el primero que llega lo obtiene; el segundo ve el motivo y una alternativa | A · 5.3 + D · 3.3 | `evidencias/conflicto.md` | ✓\* Regla y pantallas cubiertas por pruebas de integración y de la app. → La repetición con dos celulares queda para el piloto |
| Los datos sensibles solo llegan a quien corresponde | 0 filas sensibles en dispositivos no autorizados (pruebas de los streams) | A · 4.3 | `evidencias/datos-sensibles.md` | ✓ Pruebas de los streams y revocación comprobada en Android |
| La purga funciona | Datos borrados al reconectar, al vencer la caducidad y al cerrar sesión | A · 2.2–2.4 y 5.4 | `evidencias/purga.md` | ✓ En Android (iPhone omitido con autorización) |
| El ingreso con número real funciona | Un vecino recibe el SMS, entra y elige su zona | B · 1.4 | `evidencias/otp.md` y [ADR 0009](../adr/0009-proveedor-de-codigos-firebase.md) | ◐ Firebase Authentication integrado y con pruebas automatizadas; falta registrar la prueba manual en el Redmi |
| La capacidad en un pico de emergencia | p95 y tasa de error dentro de lo acordado; la cola crítica no se degrada | B · 6.1–6.3 | `evidencias/capacidad.md` | ◐ Escenario completo y humo local. → La corrida completa se hace en staging |
| Los mapas offline son viables y están permitidos | Términos que permiten el uso offline; tamaño aceptable en gama baja | C · 1.1 y 2.2–2.3 | [ADR 0008](../adr/0008-fuente-de-teselas.md) y `evidencias/mapas.md` | ◐ Fuente y términos aprobados; descarga por región integrada y probada con dobles. → Tamaño en gama baja y modo avión en el piloto |
| Avisos por token y por tópico | Llega un aviso personal y uno de zona, sin datos sensibles en el texto | C · 4.4 | `evidencias/avisos.md` | ◐ Backend (FCM y tópicos) y app integrados; los textos genéricos están probados. → La recepción en el celular requiere la cuenta de servicio y se hace en el piloto |
| El stack es compatible entre sí | Compila, sincroniza y se despliega en Android e iOS | Cimientos 3.3 + A · 6.2 | CI en verde en `main` | ◐ Compila en CI para Android e iOS y sincroniza en Android. → El despliegue llega con staging |

Los criterios de la Fase 1 repiten con datos del piloto los que aquí quedan marcados con →.
