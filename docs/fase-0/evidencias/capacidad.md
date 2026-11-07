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

## Corrida definitiva local

Ejecutada sobre `bb220e52f494292dd241fc6500c2f0214d921ac2`, con árbol limpio, el
2026-11-07 a las 16:03 UTC. Entorno: Apple M1, 8 núcleos lógicos, 8 GiB RAM, macOS arm64;
Node 26.13.0, PostgreSQL 18.6, PostGIS 3.7.0 y k6 2.3.0. API, workers, generador y base
comparten la laptop; no hay tamaño de staging que informar porque no existe ese entorno.

Comando: `DATABASE_URL_ADMIN=<base local autorizada> npm run test:load:smoke`.
El reporte anónimo de uso de k6 está desactivado en los comandos entregados.
Datos sanitizados completos en [`capacidad-humo.json`](capacidad-humo.json).

| Escenario | Solicitudes | p95 | Tasa de error |
|---|---:|---:|---:|
| Lecturas (muro y salud) | 1834 | 4,88 ms | 0 % |
| Escrituras idempotentes | 520 | 7,39 ms | 0 % |
| Reconexión (credenciales) | 260 | 5,04 ms | 0 % |

Son 2614 solicitudes de negocio en 30 segundos, aproximadamente **87,1/s** bajo el modelo
cerrado de 10 VUs. El monitoreo administrativo es adicional. No se extrapola ese valor a
2500/s. De 52 reintentos programados (10 % de las escrituras), 35 recibieron la respuesta
guardada y 17 recibieron el 409 esperado `solicitud_en_curso` con `Retry-After`; se muestran
separados y no se esconden como altas completadas adicionales.

Se recogieron 30 muestras. La cola crítica tuvo un máximo de **1 pendiente** y una edad
máxima elegible de **0,448 s**. Ejemplos de la serie:

| Tiempo | Críticos pendientes | Edad crítica | Outbox pendiente |
|---:|---:|---:|---:|
| 0,01 s | 1 | 0,179 s | 0 |
| 6,54 s | 0 | 0 s | 12 |
| 14,98 s | 0 | 0 s | 3 |
| 22,81 s | 0 | 0 s | 15 |
| 30,13 s | 0 | 0 s | 0 |

El outbox terminó sin pendientes ni edad. Se observaron 33 sondas críticas procesadas durante
la ejecución y los controles, y 3020 logs de solicitudes correlacionados. Se verificó que
los logs no contienen los accesos del archivo de carga ni las claves generadas. El archivo
de tokens se eliminó al cerrar; también se eliminaron base y procesos temporales.

Los controles negativos devolvieron **salida 99** en ambos casos: k6 rechazó el p95 imposible
y rechazó la cola crítica detenida con límite cero. Ambos ejercitaron las solicitudes y
produjeron un resumen con el umbral específico en falso; no son errores de arranque.

Conclusión del humo: funcionan el recorrido HTTP, la idempotencia, la correlación, el relay,
las métricas actuales y los umbrales de rechazo en este entorno local. Los trabajos normales
sin manejador del Lote C permanecen en su cola; no se declaran notificaciones entregadas.
La certificación del pico completo, el dimensionamiento de réplicas y la aceptación con
consumidores de negocio siguen pendientes de staging.

## CI remoto

Ejecuciones manuales sobre `bb220e52f494292dd241fc6500c2f0214d921ac2`, completadas en verde:

- [Backend](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42389285629):
  tipos, lint, formato, fronteras, Sync Streams, 144 unitarias y build; 102 integraciones con
  PostgreSQL 18 + PostGIS 3.6; humo k6 de 30 segundos y ambos controles negativos.
- [Especificaciones](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42389288009):
  OpenSpec estricto y contrato OpenAPI.

Las tareas 6.1–6.4 están verificadas. El cambio completo queda en **24/25**; únicamente 1.4
permanece abierta por la prueba manual real de Twilio. El commit posterior al código solo
registra evidencia y tareas, sin modificar la implementación ni crear un PR.

## Reproducción y pendientes

Comandos, variables, reglas de credenciales y significado de las métricas en
[`backend/test/load/README.md`](../../../backend/test/load/README.md).

Pendientes externos: disponer de staging aislado, acordar umbrales de aceptación, ejecutar
el pico completo con los consumidores de negocio necesarios y realizar la prueba real de
Twilio de la tarea 1.4. La revisión/aprobación del lote y cualquier integración a `main`
siguen a cargo del equipo. No se archiva OpenSpec.
