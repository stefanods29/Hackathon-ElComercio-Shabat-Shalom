# ADR 0011 · Confirmación de residencia para el piloto

Estado: propuesto para revisión del equipo.

## Contexto

El piloto necesita comprobar que el vecino pertenece a la zona donde participa. Usar un historial
de coordenadas para esa comprobación expondría sus desplazamientos. También debe haber una vía
para quien no quiera dar su consentimiento o no pueda informar presencia desde el celular.

## Decisión

- El celular determina si estuvo dentro del polígono y, con consentimiento vigente para
  `confirmacion_por_presencia`, puede informar `{ fecha, dentroDeLaZona }`. El servidor acepta
  una decisión por día calendario en Lima, sin coordenadas. Solo cuentan las respuestas
  afirmativas en tres fechas distintas entre hoy y los trece días anteriores, durante la
  residencia actual. Con ellas se pasa del nivel 0 al 1.
- Un moderador puede confirmar la residencia manualmente con un motivo. La auditoría guarda a
  quién confirmó, quién lo hizo, la zona, el nivel y el momento. El nivel manual por defecto es
  1; el moderador puede asignar el 2 para iniciar el sistema de avales.
- Dos avales distintos elevan a nivel 2 a un vecino cuya residencia ya fue confirmada. Cada
  avalista debe tener al menos nivel 2 y pertenecer a la misma zona. No se permite el autoaval ni
  se cuenta el mismo aval dos veces.
- Elegir de nuevo la misma zona no cambia el nivel ni reinicia el plazo. Elegir otra zona se
  permite al cumplirse 30 días desde la última elección o cambio: vuelve a nivel 0, limpia las
  presencias y los avales de la residencia anterior y registra `identidad.zona_cambiada`.
- Las presencias se eliminan al cumplir 30 días mediante un trabajo diario. Si el vecino se
  opone a este tratamiento, se registra su rechazo, se eliminan las presencias y se conserva el
  nivel ya confirmado.

## Consecuencias

El servidor conserva una señal de residencia, sin almacenar los puntos que la originaron. Los
informes de presencia proceden del celular; no sustituyen la comprobación manual en casos
dudosos. La confirmación manual y el arranque de avales dependen de moderadores del piloto. Las
tablas de identidad del ADR quedan fuera de PowerSync. El siguiente token refleja las
promociones; un token anterior pierde los permisos de la zona que el vecino dejó.
