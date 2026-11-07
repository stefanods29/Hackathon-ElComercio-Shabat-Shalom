# Spec Delta

## Purpose

Entregar de forma confiable los eventos del outbox a los procesos en segundo plano (moderación, notificaciones, rankings), sin perderlos ni bloquear la API.

## ADDED Requirements

### Requirement: Del outbox a la cola
Un relay SHALL publicar en la cola de trabajos cada evento pendiente del outbox y marcarlo como publicado; si el relay se detiene, MUST retomar desde los eventos no publicados sin perder ninguno.

#### Scenario: El worker se reinicia
- **WHEN** el proceso de workers se reinicia con eventos pendientes en el outbox
- **THEN** al volver publica esos eventos y cada uno se procesa

### Requirement: Procesamiento al menos una vez
Los manejadores de trabajos SHALL ser idempotentes, porque un trabajo puede entregarse más de una vez.

#### Scenario: Trabajo entregado dos veces
- **WHEN** el mismo evento `solidaridad.favor_tomado` llega dos veces al manejador de avisos
- **THEN** el vecino recibe un solo aviso

### Requirement: Reintentos y cola de fallidos
Un trabajo que falla SHALL reintentarse con espera exponencial un número acotado de veces y luego MUST pasar a una cola de fallidos visible para el equipo.

#### Scenario: Proveedor de avisos caído
- **WHEN** el envío de un aviso falla cinco veces seguidas
- **THEN** el trabajo queda en la cola de fallidos con el error registrado

### Requirement: Prioridad crítica
Los trabajos de prioridad crítica (emergencias) SHALL procesarse antes que los normales cuando compiten.

#### Scenario: Pico de trabajos
- **WHEN** hay mil trabajos normales pendientes y llega uno crítico
- **THEN** el crítico se procesa antes que los normales pendientes

### Requirement: Limpieza programada
Un trabajo programado SHALL borrar periódicamente las claves de idempotencia vencidas y los eventos del outbox ya publicados con más de 30 días.

#### Scenario: Limpieza diaria
- **WHEN** corre la limpieza programada
- **THEN** desaparecen las claves vencidas y el outbox antiguo ya publicado
