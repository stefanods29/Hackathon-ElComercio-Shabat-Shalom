# Spec Delta

## Purpose

Que cualquier vecino entre a la app con su número de teléfono y un código de un solo uso, sin contraseñas y sin que el sistema sea abusable.

## ADDED Requirements

### Requirement: Solicitar el código
`POST /v1/auth/otp` SHALL enviar un código de un solo uso al teléfono indicado mediante el proveedor configurado y responder igual exista o no la cuenta, para no revelar quién está registrado.

#### Scenario: Teléfono nuevo
- **WHEN** alguien pide un código para un número nunca registrado
- **THEN** recibe la misma respuesta que un usuario existente y el código llega por SMS o WhatsApp

### Requirement: Verificar el código
`POST /v1/auth/otp/verificar` SHALL aceptar el código una sola vez y dentro de su vigencia; si el teléfono no existía, MUST crear el usuario con nivel de confianza 0 y responder con un token de acceso y un refresh token.

#### Scenario: Código correcto
- **WHEN** el vecino ingresa el código recibido dentro de los 5 minutos
- **THEN** obtiene su sesión y queda registrado con nivel 0

#### Scenario: Código reutilizado
- **WHEN** alguien intenta usar el mismo código por segunda vez
- **THEN** la API responde 401 y no crea una sesión

### Requirement: Límites contra abuso
La API SHALL limitar las solicitudes y los intentos fallidos de código por teléfono y por IP, y MUST responder 429 con `Retry-After` al superarlos.

#### Scenario: Fuerza bruta
- **WHEN** se prueban 5 códigos incorrectos seguidos para el mismo teléfono
- **THEN** los siguientes intentos reciben 429 durante el tiempo de bloqueo

### Requirement: Proveedor intercambiable
El envío de códigos SHALL pasar por un puerto con un adaptador falso para desarrollo y pruebas, de modo que ningún entorno de prueba envíe mensajes reales.

#### Scenario: Pruebas automatizadas
- **WHEN** corren las pruebas de integración
- **THEN** usan el adaptador falso y ningún SMS sale del sistema
