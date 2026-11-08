# Spec Delta

## Purpose

Que un aviso urgente a un coordinador o brigadista nunca dependa de un solo canal, sin datos
sensibles y con un gasto acotado (sección 7.5 de la arquitectura).

## ADDED Requirements

### Requirement: Aviso urgente por token con confirmación
El trabajo `notificaciones.enviar_aviso_urgente` SHALL enviar un aviso a cada dispositivo activo del
destinatario una sola vez por `avisoId`. El aviso MUST quedar pendiente de confirmación hasta que el
destinatario lo confirme con `POST /v1/avisos-urgentes/{id}/confirmar`.

#### Scenario: Trabajo entregado dos veces
- **WHEN** el mismo aviso urgente se procesa dos veces
- **THEN** cada dispositivo recibe un solo aviso y existe una sola fila del aviso

#### Scenario: Otra persona intenta confirmarlo
- **WHEN** alguien que no es el destinatario confirma el aviso
- **THEN** la API responde 404 y el aviso sigue pendiente

### Requirement: SMS de respaldo con tope de gasto
Si el aviso no se confirma en `URGENT_ACK_TIMEOUT_SECONDS`, o no llegó a ningún dispositivo, SHALL
enviarse un SMS por el proveedor configurado. Esto vale solo si el gasto del día y del mes, sumado
el del mensaje, no supera sus topes. Si no se puede, el aviso MUST quedar `sin_respaldo` con su
motivo: `tope_de_gasto`, `sin_proveedor`, `sin_telefono` o `sms_fallido`.

#### Scenario: El token falla
- **WHEN** el destinatario no tiene dispositivos activos
- **THEN** la revisión se adelanta y se envía el SMS de respaldo

#### Scenario: Tope alcanzado
- **WHEN** el gasto del día ya llegó a `SMS_DAILY_BUDGET_CENTS`
- **THEN** no se envía el SMS y el aviso queda `sin_respaldo` con `tope_de_gasto`

#### Scenario: Confirmado a tiempo
- **WHEN** el destinatario confirma antes del plazo
- **THEN** la revisión no envía ningún SMS

### Requirement: Proveedor falso fuera de producción
`SMS_PROVIDER=fake` MUST NOT usarse en producción. `SMS_PROVIDER=none` SHALL dejar el respaldo
apagado y registrar cada caso como `sin_respaldo`/`sin_proveedor`.

#### Scenario: Arranque en producción con el proveedor falso
- **WHEN** la API arranca con `NODE_ENV=production` y `SMS_PROVIDER=fake`
- **THEN** la configuración se rechaza con el motivo

### Requirement: Plantillas genéricas
El texto del aviso urgente, del SMS y del aviso de zona MUST ser genérico. Nunca lleva nombres,
teléfonos, ubicaciones, datos de salud ni el tipo de necesidad. Los datos del aviso SHALL llevar
solo identificadores.

#### Scenario: Pantalla bloqueada
- **WHEN** llega un aviso urgente con el celular bloqueado
- **THEN** se ve "Tienes una actualización urgente" y nada del caso

### Requirement: Aviso público de zona
Al recibir `emergencias.evento_activado`, el sistema SHALL avisar por el tópico `zona-<zonaId>` que
se activó el modo emergencia, una sola vez por evento y zona.

#### Scenario: Evento publicado dos veces
- **WHEN** el relay entrega dos veces el mismo `emergencias.evento_activado`
- **THEN** el tópico recibe un solo aviso

### Requirement: Medición de entrega y costo
`GET /v1/operacion/avisos-urgentes/resumen` SHALL devolver, para administradores y coordinadores,
los totales por estado, la latencia de confirmación (p50 y p95), los SMS enviados y el gasto del día
y del mes frente a sus topes, sin teléfonos ni contenido.

#### Scenario: Revisión del costo
- **WHEN** un administrador consulta el resumen
- **THEN** ve el gasto del día y del mes en centavos, junto a sus topes
