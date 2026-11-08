# Monitoreo con información limitada

El backend exporta trazas, métricas y registros técnicos por OTLP HTTP solo cuando existe
`OTEL_EXPORTER_OTLP_ENDPOINT`. `SENTRY_DSN` habilita el envío opcional de errores. Sin esas
variables el funcionamiento normal no depende de servicios de monitoreo.

La instrumentación es manual: duración y resultado de los controladores que alcanzan el
interceptor, ciclos del worker y errores 5xx. No cubre automáticamente peticiones rechazadas
por los guards ni todas las conexiones internas. Los servicios se identifican como
`vecinal-api` y `vecinal-media-worker`; el entorno procede de `APP_ENVIRONMENT`.

Solo se conservan método, plantilla de ruta, resultado y clase conocida del error. Se descartan
consultas, cuerpos, cabeceras, tokens, identificadores de vecinos, coordenadas y excepciones
originales. Sentry reconstruye el evento desde una lista permitida: no envía pila, contexto,
usuario, breadcrumbs, captura de pantalla ni contenido del vecino. Esta decisión reduce la
información disponible para investigar fallos y se debe revisar con el equipo antes del piloto.

La app usa el SDK **Dart** `sentry`, sin plugin nativo de Sentry. Los errores del framework y
del hilo principal pasan por manejadores explícitos y el mismo filtrado. Se conserva la
configuración Android mínima del proyecto (API 24). No se ofrece captura de fallos nativos,
replay, perfiles ni métricas móviles. El cambio final de SDK no se recompiló por indicación
del usuario; ver el informe de evidencias.

El recolector local recibe OTLP en 4318, vuelve a aplicar una lista permitida y escribe solo
eventos técnicos en consola. La publicación del puerto en Compose está limitada a loopback.
No es un almacenamiento histórico ni un panel de producción. En cloud se requiere un destino
privado acordado, con TLS/autenticación, acceso limitado y política de retención.

La configuración se comprobó con el binario oficial
[OpenTelemetry Collector Contrib 0.148.0](https://github.com/open-telemetry/opentelemetry-collector-releases/releases/tag/v0.148.0),
verificando su SHA-256. La recepción con servicios y credenciales reales sigue pendiente.
