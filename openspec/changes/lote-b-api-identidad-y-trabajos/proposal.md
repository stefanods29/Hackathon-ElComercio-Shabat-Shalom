# Proposal

## Why

La API de los cimientos usa una sesión de desarrollo y una cola en memoria. Para la Fase 0 hace
falta la identidad real (OTP, sesiones revocables, niveles de confianza), el procesamiento
confiable de eventos en segundo plano y la prueba de capacidad del pico de emergencia
(sección 13.1). **Dueño: Lote B · Dificultad 4/5.**

## What Changes

- **Inicio de sesión con OTP** por SMS o WhatsApp detrás de un puerto (`OtpProvider`) con un
  adaptador falso para desarrollo y uno real; límites de intentos por teléfono y por IP.
- **Sesiones**: token de acceso corto + *refresh token* rotativo con detección de reutilización,
  cierre de sesión y revocación de todas las sesiones (teléfono perdido, sección 8.4).
- **Roles y niveles de confianza** aplicados en la API (decoradores de autorización).
- **Eventos y trabajos**: adaptador de `JobQueue` sobre pg-boss, relay del outbox a la
  cola, proceso de *workers* con reintentos y cola de fallidos, limpieza de idempotencia vencida.
- **Muro completo**: búsqueda por cercanía (PostGIS), cancelar y resolver un favor, límites
  diarios antifraude.
- **Capacidad**: escenario k6 del pico de emergencia (~2 500 peticiones por segundo más la
  reconexión de miles de clientes) e instrumentación mínima.

Fuera de alcance: validación de DNI (nivel 3) y consola web (Fase 2), Valkey/BullMQ (Fase 3).

## Capabilities

### New Capabilities
- `identidad/inicio-de-sesion`: registro e inicio de sesión con código de un solo uso.
- `identidad/sesiones`: renovación, cierre y revocación de sesiones.
- `identidad/roles-y-confianza`: qué puede hacer cada nivel y cada rol.
- `plataforma/eventos-y-trabajos`: entrega confiable de eventos del outbox a los workers.
- `plataforma/capacidad`: comportamiento bajo el pico de una emergencia.

### Modified Capabilities
- `solidaridad/muro-de-favores`: se agregan búsqueda por cercanía, cancelar/resolver y límites diarios.

## Impact

`backend/src/modules/identidad/`, `backend/src/modules/solidaridad/`,
`backend/src/shared/colas/` (adaptador pg-boss), `backend/src/workers/` (nuevo),
`backend/test/carga/` (nuevo), `contracts/openapi.yaml` (nuevas rutas `/v1/auth/*` y del muro).
