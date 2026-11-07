# notificaciones/avisos-push Specification

## Purpose
Avisar a los vecinos por notificaciones push como un canal más, nunca el único canal crítico, y sin exponer datos sensibles en la pantalla bloqueada (sección 7.5).

## Requirements

### Requirement: Registro del dispositivo
`POST /v1/dispositivos` SHALL registrar o actualizar el token push del celular del vecino de forma idempotente, y al cerrar sesión el token MUST darse de baja.

#### Scenario: El token cambia
- **WHEN** Firebase entrega un token nuevo al celular
- **THEN** la app lo registra y los avisos personales llegan al token nuevo

### Requirement: Avisos públicos por zona
Los avisos de zona SHALL enviarse por el tópico `zona-<id>` y MUST contener solo información pública.

#### Scenario: Se activa el modo emergencia en la zona
- **WHEN** un coordinador activa el modo emergencia de la zona piloto
- **THEN** los celulares suscritos al tópico de esa zona reciben un aviso público

### Requirement: Avisos personales sin datos sensibles
Los avisos personales SHALL enviarse al token del dispositivo con un texto genérico ("Tienes una actualización"); el detalle MUST verse solo dentro de la app, después de autenticarse.

#### Scenario: Pantalla bloqueada
- **WHEN** llega un aviso personal con el teléfono bloqueado
- **THEN** el texto visible no incluye nombres, ubicaciones ni condiciones de salud

### Requirement: Abrir la pantalla correcta
Tocar un aviso SHALL abrir la pantalla relacionada dentro de la app, pidiendo iniciar sesión primero si hace falta.

#### Scenario: Aviso de un favor tomado
- **WHEN** el autor toca el aviso de que tomaron su favor
- **THEN** la app abre el detalle de esa publicación

### Requirement: Envío confiable y reemplazable
El envío SHALL pasar por un puerto con adaptador FCM y adaptador falso, procesarse como trabajo en segundo plano con reintentos, y ser idempotente si el trabajo llega dos veces.

#### Scenario: Trabajo duplicado
- **WHEN** el trabajo `notificaciones.enviar_aviso` se entrega dos veces
- **THEN** el vecino recibe un solo aviso
