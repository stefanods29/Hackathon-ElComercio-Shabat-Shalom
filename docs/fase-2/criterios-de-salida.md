# Criterios de salida de la Fase 2

La condición de la sección 12 es "cobertura operativa en la zona y un simulacro con los aliados".
Los tiempos son los que se acuerden con los aliados (decisión 13.3.6); los de abajo son el ejemplo
de la sección 9.2.

| Criterio | Aceptación (ejemplo) | Lote · parte | Evidencia | Estado |
|---|---|---|---|---|
| Hay cobertura operativa | La zona tiene al menos 2 coordinadores activos y un turno definido (sección 9.3); sin cobertura, la API no acepta pedidos y la app explica por qué | B · 1 y 5 + D · 1 | `evidencias/cobertura.md` | ☐ |
| Las alianzas están firmadas | Acuerdos formales con los aliados que asumen roles (municipalidad o serenazgo, bomberos, centros de salud u otros) | Todo el equipo | `evidencias/alianzas.md` (sin datos personales) | ☐ |
| La privacidad se evaluó antes de activar | Evaluación de impacto hecha y sus medidas aplicadas | Todo el equipo, con A | `evidencias/impacto-privacidad.md` | ☐ |
| Los datos sensibles solo llegan a quien corresponde | 0 filas sensibles en dispositivos no autorizados en la prueba de penetración (OWASP MASVS y API Top 10) | A · 5 | [penetracion](evidencias/penetracion.md) | ☐ |
| Los tiempos de respuesta se cumplen en el simulacro | Primera revisión dentro del tiempo acordado para cada prioridad; el escalamiento automático se dispara cuando no se cumple | B · 3 + C · 2 | [simulacro](evidencias/simulacro.md) | ☐ |
| Ningún pedido se pierde | 0 pedidos perdidos o duplicados en el simulacro, incluidos los creados sin señal | A · 1 y 6 | [simulacro](evidencias/simulacro.md) | ☐ |
| Los avisos urgentes llegan | El aviso a coordinadores llega por token y, si falla, por SMS de respaldo; ningún texto lleva datos sensibles | C · 4 | `evidencias/avisos-urgentes.md` | ☐ |
| El modo operativo protege los datos | Bloqueo con PIN o biometría, cierre por inactividad, capturas bloqueadas y caducidad local verificados en Android e iOS | A · 3 | [modo-operativo](evidencias/modo-operativo.md) | ☐ |
| Quien pide ayuda entiende qué pasa | En el simulacro, los vecinos identifican el estado de su pedido y las alternativas oficiales sin ayuda | D · 2 + A · 6 | [simulacro](evidencias/simulacro.md) | ☐ |
| Hay revisión después del evento | Revisión sin culpables del simulacro, con los ajustes acordados y los casos cerrados y anonimizados (sección 9.6) | B · 5 + todo el equipo | [revision-simulacro](evidencias/revision-simulacro.md) | ☐ |

Si un criterio no se cumple, el equipo decide si se corrige antes de salir o si se acepta el riesgo
de forma explícita, y lo anota debajo de esta tabla con fecha. El riesgo residual del teléfono
perdido sin conexión (sección 8.4) se acepta aquí por escrito.

## Decisiones y riesgos

Revisión del 8 de noviembre de 2026 sobre `main` en `4fb7761` y las ramas disponibles.
Los documentos de penetración, campo y simulacro registran preparativos y comprobaciones
parciales. Las casillas de salida siguen abiertas.

| Decisión | Estado |
|---|---|
| Alianzas firmadas (13.3.2) | Pendiente de referencia a los acuerdos, sin datos personales. |
| Tiempos y caducidades definitivos (13.3.6) | Pendiente de aprobación con los aliados. |
| Evaluación de impacto en la privacidad | Pendiente de constancia y medidas verificadas. |
| Teléfono perdido sin conexión (8.4) | Pendiente de prueba y aceptación escrita con fecha. Un equipo desbloqueado y sin conexión puede exponer el detalle hasta que caduque. La revocación corta la renovación de credenciales y los JWT emitidos conservan su ventana de vigencia. |
| SMS de respaldo (12.3) | Pendiente de decisión de proveedor y topes, o aceptación escrita del riesgo con fecha. |

Para registrar una aceptación, anotar fecha, decisión, controles aplicados, evidencia y
responsables por usuario de GitHub. El estado de dependencias se detalla en el
[seguimiento del pendiente 13](evidencias/README.md#pendiente-13).
