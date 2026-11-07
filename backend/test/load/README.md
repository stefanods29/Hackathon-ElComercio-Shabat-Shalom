# Capacidad · Lote B, Parte 6

Requiere Node 26, PostgreSQL 18 con PostGIS y **k6 2.3.0**. No usa Grafana Cloud ni envía
telemetría a un servicio externo; las peticiones van únicamente a la API elegida.

## Humo local reproducible

Desde `backend/`:

```bash
npm ci
npm run build
DATABASE_URL_ADMIN=postgres://postgres:postgres@localhost:5432/postgres npm run test:load:smoke
```

El ejecutor crea una base temporal y 100 usuarios sintéticos con sesiones revocables, inicia
la API y los workers en procesos separados y ejecuta `k6 run --vus 10 --duration 30s`.
No habilita la sesión de desarrollo ni envía OTP. Un consumidor de prueba procesa una sonda
crítica cada segundo para comprobar medición real de pg-boss, independiente de los consumidores
de negocio que incorporará el Lote C.

También ejecuta dos controles de dos segundos que **deben fallar**: latencia permitida de
0,000001 ms y cola crítica detenida con límite de pendientes cero. El humo global falla si
esos controles no son rechazados por sus umbrales específicos.

Al terminar conserva logs JSON, muestras y un informe local sin credenciales en el directorio
temporal indicado. Elimina el archivo de tokens, detiene los procesos y borra su base. Para
copiar solo el informe sanitizado a una ruta conocida:

```bash
DATABASE_URL_ADMIN=postgres://postgres:postgres@localhost:5432/postgres \
  npm run test:load:smoke -- --report capacity.load-summary.json
```

## Corrida completa en staging

Se requiere un entorno **aislado de carga**, con el código de las Partes 1–6, API y workers,
sus claves configuradas y la zona de prueba existente. Este trabajo no proporcionó staging;
el humo local no certifica 2500 solicitudes/s.

Con el entorno del backend apuntando a esa base y usando las mismas claves que la API:

```bash
npm run load:tokens -- --count 30000 --zone UUID_DE_LA_ZONA \
  --base-url https://staging.example.test --output tokens.load-tokens.json

PROFILE=peak TOKENS_FILE=tokens.load-tokens.json \
  BASE_URL=https://staging.example.test SUMMARY_PATH=capacity.load-summary.json \
  npm run test:load
```

El archivo de tokens es 0600 y queda fuera de Git. Se rechaza sobrescribirlo; genera uno nuevo
si vence. El script crea identidades sintéticas con prefijo telefónico no operativo `+999`,
no llama a OTP y descarta los refresh secretos después de guardar sus hashes. Incluye un
observador administrador únicamente para las métricas. No uses datos de vecinos ni la sesión
de desarrollo. Destruye el entorno aislado de carga al acabar y elimina las credenciales locales.

Con el límite de 10 publicaciones/24 h se necesitan al menos **27000 usuarios sin publicaciones
previas** para las 270000 altas previstas; 30000 deja margen. La corrida comprueba ese presupuesto
y el vencimiento de los accesos antes de empezar. No aumenta ni desactiva el límite del servidor.
`--lat` y `--lng` permiten elegir un punto sintético de la zona; por defecto se usa el piloto.

## Mezcla y umbrales

El perfil `peak` dura 10 minutos. Lecturas y escrituras usan `constant-arrival-rate` a 1750 y
500 iteraciones/s; reconexión usa `ramping-arrival-rate` con base 250/s, dos picos a 500/s y
jitter de hasta 200 ms. Cada iteración realiza una solicitud de negocio. El monitoreo añade
aproximadamente una solicitud administrativa por segundo, fuera de la mezcla.

Las lecturas alternan muro por cercanía y salud. Las escrituras usan UUIDv7 y `Idempotency-Key`;
un índice lógico compartido entre VUs repite exactamente una solicitud de cada diez con el
mismo actor, cuerpo e id. Un 409 `solicitud_en_curso` con `Retry-After` es una contención esperada,
registrada por separado; otros 4xx/5xx cuentan como error. No hay reintentos ocultos.

El perfil `smoke` usa un modelo cerrado con 10 VUs y pausa de 100 ms, conservando la proporción
70/20/10. Sirve para verificar el recorrido, no para fijar una tasa de llegada.

| Variable de k6 | Predeterminado | Significado |
|---|---|---|
| `PROFILE` | `smoke` | `peak` habilita el escenario completo |
| `DURATION` | `30s` / `10m` | Duración de humo / pico |
| `RATE_SCALE` | `1` | Factor de tasas del pico entre 0,001 y 1 |
| `READ_P95_MS` | `300` | p95 máximo de lecturas |
| `WRITE_P95_MS` | `500` | p95 máximo de escrituras |
| `RECONNECT_P95_MS` | `300` | p95 máximo de credenciales |
| `MAX_ERROR_RATE` | `0.01` | Error por escenario y global; cero exige cero errores |
| `MAX_CRITICAL_PENDING` | `100` | Máximo de trabajos críticos pendientes |
| `MAX_CRITICAL_AGE_SECONDS` | `30` | Edad máxima del crítico listo más antiguo |

Estos valores son **provisionales**, tomados de la guía. El equipo debe acordar los de aceptación
en staging y pasarlos explícitamente. El pico falla también si k6 descarta iteraciones por falta
de VUs. El monitor exige pg-boss real y muestras válidas: no sustituye una cola ausente por cero.

## Interpretación

`handleSummary` entrega p95, tasa de error y volumen por escenario, replays/contenciones y
máximos de cola crítica. La salida de consola contiene muestras numéricas periódicas con
outbox y cola crítica; `--console-output=muestras.jsonl --log-format=json` las conserva.
Las métricas de idempotencia pertenecen a la instancia consultada desde su arranque;
outbox y colas se leen de PostgreSQL. En un despliegue con réplicas, recoge cada instancia.

El humo no mide la red móvil, el servicio PowerSync ni proveedores de notificaciones: mide
la API de credenciales y los componentes de backend. Las colas de negocio sin manejador
pueden acumular trabajos; no se interpreta esa acumulación como avisos entregados.

Referencias: [arrival-rate](https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/constant-arrival-rate/),
[ramping-arrival-rate](https://grafana.com/docs/k6/latest/using-k6/scenarios/executors/ramping-arrival-rate/),
[resumen personalizado](https://grafana.com/docs/k6/latest/results-output/end-of-test/custom-summary/).
