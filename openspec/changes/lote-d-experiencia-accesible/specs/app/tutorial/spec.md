# Spec Delta

## Purpose

Que un vecino que nunca usó la app aprenda a publicar y a tomar un favor en minutos, sin miedo a equivocarse.

## ADDED Requirements

### Requirement: Tutorial sobre la pantalla real
La primera vez que se abre la app SHALL mostrarse un tutorial con indicaciones sobre la pantalla real (no capturas), que se puede saltar y repetir desde el menú.

#### Scenario: Primer uso
- **WHEN** un vecino abre la app por primera vez
- **THEN** el tutorial resalta el botón "+" y explica para qué sirve

### Requirement: Modo práctica
El tutorial SHALL incluir un "modo práctica" donde las publicaciones de prueba MUST NOT enviarse al servidor ni verse por otros vecinos.

#### Scenario: Publicación de práctica
- **WHEN** el vecino publica en modo práctica
- **THEN** la publicación se marca "De práctica" y no entra en la cola de envío

### Requirement: Explicar el trabajo sin conexión
El tutorial SHALL explicar con un ejemplo qué significa "Guardado en tu celular" y qué hacer si hay riesgo para la vida (116, 105 o 106).

#### Scenario: Paso sobre la falta de señal
- **WHEN** el vecino llega al paso sobre la falta de señal
- **THEN** ve que lo guardado no le llega a nadie hasta que haya conexión
