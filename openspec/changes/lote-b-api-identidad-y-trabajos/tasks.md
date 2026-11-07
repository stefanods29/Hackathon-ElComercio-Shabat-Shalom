# Tasks

## 1. Parte 1 · Inicio de sesión con OTP

- [x] 1.1 Agregar `/v1/auth/otp` y `/v1/auth/otp/verificar` a `contracts/openapi.yaml`; verificar con `redocly lint`
- [x] 1.2 Migración `identidad.codigos_otp` (hash del código, vigencia, intentos) y puerto `OtpProvider` con adaptador falso; verificar con pruebas unitarias
- [x] 1.3 Casos de uso solicitar y verificar (registro con nivel 0) y límites por teléfono e IP (429 + `Retry-After`); verificar con pruebas de integración
- [ ] 1.4 Adaptador real (Twilio Verify o Firebase) detrás de configuración; verificar con una prueba manual documentada
- [x] 1.5 Zonas: `GET /v1/zonas` (pública, sin polígono) y `PUT /v1/yo/zona` (una sola vez; devuelve un token de acceso con la zona nueva; 409 `zona_ya_elegida` si ya tenía); verificar con pruebas de integración
- [x] 1.6 Compilar y depurar: `npm run verify` y `npm run test:integration` en verde

## 2. Parte 2 · Sesiones revocables

- [x] 2.1 Migración `identidad.sesiones` (familia, hash del refresh, dispositivo, revocada_en); verificar con pruebas de integración
- [x] 2.2 `POST /v1/auth/refrescar` con rotación y detección de reutilización; verificar con una prueba de token robado
- [x] 2.3 `POST /v1/auth/cerrar-sesion` y `POST /v1/auth/sesiones/revocar`; verificar que `GET /v1/sync/credenciales` responde 401 después
- [ ] 2.4 Compilar y depurar (CI en verde)

## 3. Parte 3 · Roles y niveles de confianza

- [ ] 3.1 Decoradores `@RequireTrustLevel(n)` y `@RequireRole(...)` con guard; verificar con pruebas por cada combinación
- [ ] 3.2 Aplicarlos a las rutas existentes y documentarlos en el contrato; verificar con pruebas de punta a punta
- [ ] 3.3 Compilar y depurar (CI en verde)

## 4. Parte 4 · Eventos y trabajos

- [ ] 4.1 Adaptador pg-boss de `JobQueue` (prioridad, reintentos, cola de fallidos) en el esquema `colas`; verificar con pruebas de integración
- [ ] 4.2 Relay del outbox con `SKIP LOCKED`; verificar con una prueba de dos relays en paralelo sin duplicados
- [ ] 4.3 Proceso `src/workers/main.ts`, limpieza programada (idempotencia vencida, outbox antiguo) y contrato del trabajo `notificaciones.enviar_aviso` para el Lote C; verificar con pruebas
- [ ] 4.4 Compilar y depurar (CI en verde)

## 5. Parte 5 · Muro completo

- [ ] 5.1 Búsqueda por cercanía con `ST_DWithin` y cursor; verificar con pruebas de integración con PostGIS
- [ ] 5.2 Cancelar y resolver con versión e idempotencia; verificar con pruebas
- [ ] 5.3 Límites diarios (429 `limite_diario_alcanzado`); verificar con pruebas
- [ ] 5.4 Compilar y depurar (CI en verde)

## 6. Parte 6 · Capacidad

- [ ] 6.1 Escenario k6 en `backend/test/carga/` (pico de emergencia + reconexión con jitter); verificar con una corrida de humo local
- [ ] 6.2 Logs estructurados con `requestId` y métricas de idempotencia y outbox; verificar en una corrida de k6
- [ ] 6.3 Informe en `docs/fase-0/evidencias/capacidad.md` con p95, errores y cola crítica
- [ ] 6.4 Compilar y depurar (CI en verde)

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
