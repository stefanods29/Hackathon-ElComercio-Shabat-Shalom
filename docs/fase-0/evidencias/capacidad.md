# Capacidad · Lote B, Parte 6

Fecha: 2026-11-07. Rama: `lote-b/parte-6-capacidad`, pendiente de revisión.
La base es `af7bcd8` (Parte 5). El commit `c1c7a0c` integra `5c4d18b` (Partes 3 y 4),
con autorización explícita **solo en esta rama**. Las ramas de las Partes 1–5 se conservan,
sin cambios en `main`, sin rebase, cherry-pick ni PR. El contrato se definió antes del código
de observabilidad y quedó validado en `7436315`.

## Alcance y entorno

El equipo confirmó que no hay staging disponible. Se entrega el escenario completo de diez
minutos y aproximadamente 2500 solicitudes/s, pero se ejecuta únicamente el humo local de
10 VUs durante 30 segundos. Este resultado no certifica el pico ni sustituye la aceptación
en staging. Los umbrales de ejemplo siguen siendo provisionales hasta acordarlos con el equipo.

El ejecutor crea una base temporal con migraciones y datos sintéticos, inicia API y workers
en procesos separados, usa pg-boss real y deshabilita la sesión de desarrollo. El generador
crea sesiones revocables; no envía OTP ni mensajes. Conserva métricas y logs locales y elimina
credenciales, procesos y base al terminar. La sonda crítica es sintética, no un consumidor
de emergencias o notificaciones del Lote C.

## Implementación y pruebas

- `test/load/emergency-peak.js`: perfil completo con llegada constante en lecturas/escrituras,
  reconexión con picos y jitter, diez por ciento de replays deterministas entre VUs y monitoreo.
- El presupuesto de usuarios respeta `MAX_POSTS_PER_DAY`; no se relaja el límite de publicación.
  Con 10 altas por día, la corrida completa requiere al menos 27000 usuarios nuevos.
- `GET /v1/operacion/metricas` exige administrador. Distingue cuatro resultados de idempotencia
  por proceso, outbox pendiente/edad y profundidad actual de cada cola, incluidos críticos.
- `x-request-id` correlaciona respuesta, logs JSON y Problem Details; un rechazo guardado se
  repite con la correlación actual. No se registran consultas de URL, cuerpos, tokens ni
  mensajes de excepciones que puedan contener secretos.
- El humo incluye controles negativos de latencia imposible y cola crítica detenida: k6
  debe terminar con error por el umbral correspondiente, no por falta de configuración.
- CI añade el mismo humo y controles con k6 2.3.0 y PostgreSQL 18 + PostGIS 3.6.

Verificación local de implementación: `npm run verify` con **144 unitarias**, e integración
con **102 pruebas en 12 archivos**. Tipos, lint sin advertencias, formato, fronteras, Sync
Streams y build correctos. La prueba del relay registra un aviso esperado al simular un fallo.
El contrato conserva las tres advertencias 4xx preexistentes (salud, JWKS y zonas).

La corrida definitiva sobre un commit limpio y los enlaces de CI se registrarán a continuación.
Las tareas 6.1–6.4 permanecen sin marcar hasta reunir esa evidencia.

## Reproducción y pendientes

Comandos, variables, reglas de credenciales y significado de las métricas en
[`backend/test/load/README.md`](../../../backend/test/load/README.md).

Pendientes externos: disponer de staging aislado, acordar umbrales de aceptación, ejecutar
el pico completo con los consumidores de negocio necesarios y realizar la prueba real de
Twilio de la tarea 1.4. La revisión/aprobación del lote y cualquier integración a `main`
siguen a cargo del equipo. No se archiva OpenSpec.
