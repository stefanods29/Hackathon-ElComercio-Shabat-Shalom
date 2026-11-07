# Spec Delta

## Purpose

Saber durante el piloto si la sincronización está sana (tamaño de la cola, tiempo hasta "Enviado",
rechazos y conexión) sin recolectar datos personales (sección 11 de la arquitectura).

## ADDED Requirements

### Requirement: Contadores en el celular
La app SHALL calcular en el celular el tamaño de la cola local, el tiempo desde "Guardado en tu
celular" hasta "Enviado" (p50 y p95), los rechazos permanentes por código, el tiempo desde la
última sincronización y los errores de conexión.

#### Scenario: Tres acciones enviadas
- **WHEN** tres acciones pasan a "Enviado" después de 10, 20 y 90 segundos
- **THEN** la app calcula un p50 de 20 segundos y un p95 de 90 segundos

### Requirement: Envío agregado y anónimo
La app SHALL enviar los contadores agregados como máximo una vez al día a
`POST /v1/telemetria/sincronizacion`, con su `Idempotency-Key`, la versión de la app y el sistema
operativo. El envío MUST NOT incluir identificadores, teléfonos, contenido ni ubicaciones.

#### Scenario: Envío diario
- **WHEN** pasó un día desde el último envío y hay conexión
- **THEN** la app envía solo los campos del contrato y no repite el envío ese día

### Requirement: Contrato estricto y sin identidad
La API SHALL responder 400 si el cuerpo trae un campo que no está en el contrato, y MUST NOT guardar
quién envió las métricas.

#### Scenario: Campo no previsto
- **WHEN** el cuerpo incluye un campo `telefono`
- **THEN** la API responde 400 `validacion` y no guarda nada

#### Scenario: Envío válido
- **WHEN** un celular envía métricas válidas
- **THEN** la API guarda los contadores sin el identificador del vecino ni de su dispositivo

### Requirement: Resumen para el equipo
Las métricas operativas SHALL incluir un resumen de la sincronización de los últimos días para los
administradores, y MUST seguir reservadas a ese rol.

#### Scenario: Administrador consulta el resumen
- **WHEN** un administrador consulta `GET /v1/operacion/metricas`
- **THEN** recibe el número de reportes, el p95 del tiempo hasta "Enviado" y los rechazos por código del período

#### Scenario: Vecino sin rol
- **WHEN** un vecino sin rol de administrador consulta las métricas
- **THEN** la API responde 403
