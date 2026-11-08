# Métricas de sincronización

Fase 1 · Lote A · parte 3. Revisión de privacidad de cada campo y guía de lectura para el Lote C.

**Estado:** implementado en la rama `f1-lote-a/parte-3-metricas`. Las pruebas unitarias y de
integración están escritas y **todavía no se ejecutaron**; las cifras reales llegan con el piloto
(parte 5), sin datos personales.

## Qué envía cada celular

Como máximo un reporte al día a `POST /v1/telemetria/sincronizacion`, con su `Idempotency-Key`.
El reporte y su clave se guardan antes de enviarlos: si falla la conexión, el siguiente intento
repite el mismo cuerpo con la misma clave y el servidor no lo cuenta dos veces. El primer período
empieza la primera vez que se abre la sesión; no se envía nada antes de un día completo. En sistemas
que no son Android ni iOS no se reporta.

| Campo | Qué es | Por qué no identifica a nadie |
|---|---|---|
| `versionApp` | Versión de la app (`APP_VERSION`) | Es la misma para todos los que instalaron esa versión |
| `sistema` | `android` o `ios` | Solo el sistema, sin modelo, versión ni identificador del dispositivo |
| `periodoInicio`, `periodoFin` | Ventana de los contadores | El servidor guarda solo la duración en minutos, no las fechas |
| `colaPendientes` | Acciones en la cola local al cerrar el período | Un número, sin el tipo ni el contenido de las acciones |
| `enviosConfirmados` | Acciones que pasaron a "Enviado" en el período | Un número |
| `tiempoHastaEnviadoP50Segundos`, `tiempoHastaEnviadoP95Segundos` | Espera desde "Guardado en tu celular" hasta "Enviado" (rango más cercano) | Percentiles agregados; ninguna acción se puede reconstruir |
| `rechazosPermanentes` | Cantidad de rechazos definitivos por código del problema (`resena_duplicada`, `validacion`…), como máximo 20 | Los códigos los define la API; no llevan títulos, detalles ni ids |
| `segundosDesdeUltimaSincronizacion` | Tiempo desde la última sincronización completa | Un número, sin la hora del celular |
| `erroresDeConexion` | Veces que la conexión con PowerSync empezó a fallar mientras la app estaba abierta | Un número |

No se envían: el id del vecino o de su cuenta, el teléfono, la zona, ubicaciones, contenido de
publicaciones o reseñas, ids de recursos, claves de idempotencia de las acciones ni el modelo del
celular. El contrato es estricto: un campo de más (por ejemplo `telefono`) responde 400 `validacion`
y no se guarda nada.

## Qué guarda el servidor

- Tabla `compartido.telemetria_sincronizacion`, sin columnas de vecino ni de dispositivo. Una
  prueba de integración fija la lista exacta de columnas.
- Solo el **día** de recepción (`recibido_el`, UTC), no la hora, y un id aleatorio
  (`gen_random_uuid()`), no un UUIDv7, que lleva la hora de creación.
- El período se guarda como duración en minutos.
- La tabla no está en la publicación de PowerSync: no llega a ningún celular.

### Riesgo residual: el registro de idempotencia

La ruta exige sesión para limitar el abuso, así que el registro de idempotencia
(`compartido.idempotencia`) guarda durante su retención normal (`IDEMPOTENCY_RETENTION_HOURS`, 168 h
por defecto) el alcance del vecino, la hora exacta, la huella del cuerpo y la respuesta
(`{recibidoEl}`). Ese registro dice que un vecino envió un reporte un día, pero no cuál es su fila:
la fila no tiene la hora ni las fechas exactas del período con las que se calculó la huella. En un
piloto pequeño, un día con muy pocos reportes facilita la asociación por descarte; el contenido son
contadores sin datos personales. Si el equipo lo pide, una mejora posible es una retención más
corta para esta ruta.

## Guía de lectura para el Lote C

`GET /v1/operacion/metricas` (solo administradores) trae la sección `sincronizacion` con los
reportes de los últimos 7 días, hoy incluido. Los percentiles se calculan sobre los valores de cada
reporte (por ejemplo, el p95 de los p95 de cada celular).

| Campo | Cómo leerlo | Señal de alerta sugerida para el piloto |
|---|---|---|
| `desde` | Primer día (UTC) del resumen | — |
| `reportes` | Celulares que reportaron en la semana (cada uno, como máximo uno por día) | Cae a la mitad respecto de la semana anterior |
| `enviosConfirmados` | Acciones que llegaron al servidor | — |
| `colaPendientesP95` | Cola local al cerrar el período | Mayor que 5 durante dos días |
| `tiempoHastaEnviadoP50Segundos` | Espera típica hasta "Enviado" | Mayor que 60 s |
| `tiempoHastaEnviadoP95Segundos` | Espera de los casos lentos | Mayor que 3600 s |
| `rechazosPermanentes` | Rechazos definitivos por código | Un código nuevo o que se duplica en un día |
| `segundosDesdeUltimaSincronizacionP95` | Celulares que llevan tiempo sin sincronizar | Mayor que 86400 s |
| `erroresDeConexion` | Fallos de conexión con PowerSync | Sube sin un corte conocido de la red o del servicio |

Los umbrales son una propuesta para arrancar el piloto; se ajustan con las primeras semanas en
[`piloto.md`](piloto.md) cuando exista. El Lote C (parte 5) exporta estas mismas cifras por
OpenTelemetry a su tablero, con nombres sugeridos `vecinal.sync.reportes`,
`vecinal.sync.cola_pendientes.p95`, `vecinal.sync.tiempo_hasta_enviado.p50` y `.p95`,
`vecinal.sync.rechazos` (atributo `codigo`), `vecinal.sync.sin_sincronizar.p95` y
`vecinal.sync.errores_de_conexion`.

## Pruebas escritas (pendientes de ejecutar)

- `backend/src/shared/observability/sync-telemetry.spec.ts`: contrato estricto, campos extra,
  contadores negativos, período al revés, p50 mayor que p95, más de 20 códigos y día UTC.
- `backend/test/integration/sync-telemetry.int-spec.ts`: 202 sin identidad, reintento sin fila
  duplicada, columnas exactas, 400 `validacion` sin guardar, 401 sin sesión, resumen del
  administrador y 403 para un vecino.
- `app/test/core/sync/sync_metrics_test.dart`: p50 de 20 s y p95 de 90 s con 10, 20 y 90 s,
  ventana del período, códigos de rechazo y cuerpo con solo los campos del contrato.
- `app/test/core/sync/sync_telemetry_reporter_test.dart`: primer día sin envío, un envío al día,
  reintento con la misma clave y el mismo cuerpo, 401 pendiente, 400 descartado y borrado de las
  claves al cerrar sesión.
