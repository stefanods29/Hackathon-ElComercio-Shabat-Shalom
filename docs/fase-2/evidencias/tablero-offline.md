# Parte 4 · Tablero sin conexión

Rama `f2-lote-a/parte-4-tablero-offline`, con base en la entrega de la Parte 3 `8914d2a`.
El contrato se consultó en B `0a69b19` y el tablero de D en `1dd4388`.

## Cambios

- `agregados_de_mi_zona` lee `emergencias.agregados_celda`, donde B aplica
  `HAVING count(*) >= 3` y una restricción de tabla. `recursos_criticos_de_mi_zona` lee
  `emergencias.recursos_publicos`. Las reglas filtran por la zona del JWT y proyectan columnas
  explícitas. El detalle de pedidos, la identidad del reportante, la huella y las coordenadas
  exactas quedan fuera de estas proyecciones.
- Ambos streams se descargan automáticamente con prioridad 1. Así la copia está disponible
  para la zona antes de activar el modo emergencia y tiene prioridad sobre el tráfico ordinario
  cuando se recupera la señal. El esquema local incorpora sus dos tablas y el repositorio
  vuelve a filtrar por zona al leerlas.
- Desde el directorio de emergencia, una cuenta con zona abre el tablero en
  `/emergencia/datos-de-mi-zona`. El tablero muestra los recursos y los grupos descargados,
  conserva los números oficiales como alternativa y usa el umbral de cada fila para señalar
  cuándo el reporte pudo cambiar. La fuente oficial procede de la proyección de B. Activar
  el modo local no declara un evento ni confirma cobertura operativa.
- La política compartida de imágenes bloquea nuevas cargas de fotos en modo emergencia.
  La cola de C pausa el trabajo, pide cancelar sus subidas nativas y conserva borradores y
  claves de idempotencia. La reconexión no inicia nuevas solicitudes de la cola mientras
  sigue en pausa. Al salir, la cola retoma el trabajo. Las vistas de fotos públicas y reseñas
  también dejan de construir imágenes de red. Los metadatos del stream de reseñas se mantienen.
- Los cambios de contrato de esta entrega están en las reglas de Sync Streams y el esquema
  local. OpenAPI, las migraciones y las variables de entorno no se modificaron.

## Verificación de laboratorio

En PostgreSQL 18.6 se ejecutaron las definiciones de las proyecciones y los SQL de
agregación y publicación de B, con filas ficticias en una transacción revertida al terminar.
Se sembraron grupos de dos y tres pedidos en la zona objetivo y un grupo de tres en otra
zona. B suprimió el grupo de dos y rechazó insertarlo en la tabla pública. El evaluador de
PowerSync, con las filas producidas por ese SQL, entregó el grupo de tres y un recurso
oficial de la zona con prioridad 1, sin filas de la otra zona ni campos privados.

Flutter reabrió la copia cifrada desconectada y verificó los límites de frescura con reloj
controlado. La prueba de reconexión de la cola de C registró cero solicitudes HTTP de fotos
con un borrador pendiente mientras el modo emergencia estaba activo. Al salir, la cola
reanudó la comunicación. Otra prueba simuló una subida en curso y comprobó que la pausa
la cancela y conserva las claves del borrador para el reintento.

| Comprobación | Extracto del resultado |
| --- | --- |
| `app/tool/verify.sh` | `No issues found!` · `+247 ~1: All tests passed!` · `Formatted 211 files (0 changed)` · `✓ App verificada`. |
| `npm run verify` en backend | `246 passed (246)` pruebas · compilación NestJS. |
| `npm run test:integration` en backend | `191 passed (191)` pruebas en PostgreSQL y PostGIS. |
| Evaluador de Sync Streams | `18 passed (18)` pruebas dirigidas. Reglas válidas con cero advertencias. |
| SQL de B y evaluador | Grupo de dos suprimido, grupo de tres y un recurso oficial entregados, otra zona excluida, prioridad 1 y cero columnas privadas. |
| CDN, OpenAPI y OpenSpec | `pass 10` en CDN · OpenAPI válido con tres advertencias previas · `27 passed, 0 failed` en OpenSpec. |

La prueba de Flutter omitida requiere PowerSync en vivo. El lint del backend conserva seis
advertencias previas en pruebas de directorio y reputación. OpenSpec marca 4.1 y 4.3 por
la evidencia de laboratorio. Las tareas 4.2 y 4.4 quedan pendientes de verificar.

## Pendientes de integración

- **B.** Acordar `emergencias.recursos_publicos.verificado_en` como `timestamptz`, con la fecha
  de la verificación oficial. La fecha debe actualizarse al verificar y limpiarse cuando
  el reporte pierde su verificación. La app muestra la fuente oficial y distingue la
  fecha de reporte de la fecha de verificación, que figura como no disponible.
- **D.** Conectar el tablero de su rama al `emergencyBoardRepositoryProvider` o enlazar la
  pantalla de lectura local con `Routes.emergencyBoardData`. Adoptar la política compartida
  `imagesEnabledProvider` y activar el modo mediante `appModeProvider` cuando corresponda.
  El tablero público puede mostrar los datos descargados de la zona con independencia
  de la admisión de pedidos. La fecha de verificación del recurso depende de B.
- **CI.** Los workflows de app, backend y especificaciones no se disparan con un push a la
  rama de entrega. Queda pendiente registrar una ejecución del commit final.
