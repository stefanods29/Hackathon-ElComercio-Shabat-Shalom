# Simulacro con aliados y prueba con vecinos · A 6.1, A 6.2 y D 4.3

Libreto preparado el 8 de noviembre de 2026. Responsable: `JDiazD33`, con el equipo y los
aliados. **Ejecución pendiente.** Fecha, horario (America/Lima), alias de la zona de ensayo y
duración se asignan cuando estén documentadas las condiciones de entrada.

## Condiciones de entrada

- Registrar las alianzas firmadas y los roles, los tiempos y caducidades definitivos (13.3.6)
  y la evaluación de impacto con medidas verificadas. Revisar los pendientes 2 a 12 y registrar
  por escrito y con fecha las aceptaciones de riesgo.
- Usar una zona ficticia dedicada. Crear habilitaciones y turnos vigentes para las cuentas de
  prueba. Confirmar por API la cobertura con dos coordinadores habilitados como mínimo y un
  turno definido. Comprobar también el comportamiento de una zona de ensayo sin cobertura.
- Identificar SHA de app, API, consola y configuración PowerSync. Verificar `npm run verify`,
  integración del backend y contrato de consola, `app/tool/verify.sh`, análisis, pruebas y build
  web de la consola, OpenAPI, OpenSpec y CI sobre esos SHA. Registrar los enlaces a las corridas.
- Acordar si se ensaya SMS de respaldo y el proveedor. Abrir en la consola la cola con
  prioridad y temporizadores, el mapa de celdas, los turnos y el resumen de avisos. Comprobar
  que el historial identifica la primera revisión y los escalamientos. Preparar una hoja de
  seguimiento con alias, estado, prioridad y tiempos relativos.

| Función | Participación |
|---|---|
| Control y observación | Valida entradas y versiones. Introduce los cortes y conserva métricas agregadas. |
| Aliados | Validan el procedimiento de derivación y representan la recepción durante el ejercicio. |
| Coordinación primaria y de respaldo | Activa el evento, revisa, asigna, responde al escalamiento y cierra. |
| Brigadistas | Reciben el caso, pasan a en camino y comprueban la precisión de la vista. |
| Vecinos | Crean pedidos de prueba y consultan el estado y las alternativas sin ayuda. |

## Secuencia y seguimiento

El horario se expresa a partir de T0, inicio pactado. La duración depende de los tiempos y
caducidades aprobados. Usar casos inventados y representar las llamadas oficiales sin realizarlas.

| Tramo | Caso ficticio y acción | Registrar |
|---|---|---|
| Antes de T0 | Comprobar habilitaciones, cobertura, turnos, conectividad y versiones. | Evidencia de cobertura, verificaciones y actores por función. |
| T0 | Activar el evento. Comprobar el cambio del tablero y los avisos aplicables. | Canal, hora relativa, recepción y confirmación. |
| Tras activación | RV-01. Representar riesgo vital en el formulario. Identificar las alternativas oficiales. | Alternativa identificada y pedidos creados para este escenario, que deben ser cero. |
| Primer bloque | AL-01. Alta. Revisar dentro del plazo, asignar, marcar en camino y confirmar atención. | Recepción, primera revisión, asignación, cambio de precisión y cierre. |
| Primer bloque | AL-02. Alta. Guardar sin señal, reiniciar, reconectar en grupo y derivar. | Guardado, recepción, primera revisión, motivo ficticio y siguiente paso visibles al autor. |
| Escalamiento | ME-01. Media. Dejar vencer el plazo intencionalmente. Observar el escalamiento y revisar desde respaldo. | Plazo acordado, hora del escalamiento, destino por función, aviso y primera revisión. |
| Reconexión | BA-01. Baja. Crear sin conexión, reconectar y cerrar sin atender con motivo ficticio. | Estado guardado, acuse, resultado según la regla de baja prioridad y motivo visible. |
| Canal de respaldo | Confirmar un aviso por token. Si el SMS está aprobado, dejar vencer otro acuse y comprobar el respaldo. | Canal, hora relativa, entrega y confirmación. |
| Cierre | Comparar colas y pedidos con el [procedimiento de campo](modo-operativo.md#prueba-de-campo). Cerrar casos y evento y completar la anonimización. | Perdidos, duplicados, falta de acuse, casos cerrados y casos anonimizados. |

Medir la primera revisión desde la recepción del servidor. Registrar aparte el tiempo desde
guardado local hasta recepción. Separar el escalamiento forzado del cumplimiento normal.
Distinguir la aceptación del push por el proveedor de la recepción en el teléfono. Verificar
la anonimización con conteos de filas, sin exportar su contenido.

### Prueba con vecinos

Con un caso guardado sin señal y otro ya revisado, pedir a cada participante que diga qué pasó,
si alguien recibió el pedido y qué opción oficial usaría. Repetir con la derivación o el cierre
sin atención. Presentar la tarea sin enseñar dónde pulsar. Anotar por estado cuántas personas
lo identificaron y cuántas encontraron las alternativas sin ayuda. Registrar si alguien necesitó
una indicación. Conservar únicamente conteos y observaciones redactadas.

## Resultados

| Medición | Resultado |
|---|---|
| Primeras revisiones dentro del tiempo por prioridad | Pendiente |
| Escalamiento automático y revisión de respaldo | Pendiente |
| Pérdidas y duplicados, incluidos pedidos sin señal | Pendiente |
| Avisos recibidos y confirmados por canal | Pendiente |
| Vecinos que identifican estado y alternativas sin ayuda | Pendiente |
| Casos cerrados y anonimizados | Pendiente |

Completar la [revisión sin culpables](revision-simulacro.md) después de la corrida.
