# Parte 2 · Streams por asignación

Rama `f2-lote-a/parte-2-streams-por-asignacion`, con base en la entrega de Parte 1 `ea88f4b`.
El contrato de B se consultó en `0a69b19`. Su ruta `GET /v1/pedidos-ayuda/{id}` audita la
lectura HTTP del detalle. La apertura de un Sync Stream necesita además un permiso que las reglas
puedan verificar en el servidor.

## Cambios

- `caso_asignado` devuelve necesidad, prioridad, estado, versión, celda y fechas del pedido
  abierto. `caso_ubicacion_exacta` devuelve descripción y coordenadas solo en estado `en_camino`.
  Ambos requieren suscripción explícita, asignación vigente y permiso para el alcance y la familia
  de la sesión que se presenta.
- Las credenciales de PowerSync conservan `sid` después de validar la familia autenticada y releer
  los roles y la zona. La misma cuenta en dos celulares recibe familias distintas.
- La app solicita la apertura antes de suscribirse. Ante un 403, una ruta ausente o una respuesta
  inválida, el cliente carece de permiso y no abre el stream. El resumen y el detalle exacto usan
  bases cifradas y claves separadas. Al salir de `en_camino` o perder el permiso exacto, la app
  elimina de memoria el detalle y borra su archivo y su clave. El cierre, la reasignación, el
  vencimiento del permiso de resumen y el cierre de sesión purgan ambas bases. La reapertura
  puede restaurar un resumen vigente y exige una apertura nueva para la ubicación exacta.
- La entrega cambia la configuración de streams, el esquema local y el claim de sesión que llega
  a PowerSync. El contrato de OpenAPI, las migraciones y las variables de entorno pertenecientes
  a la ruta propuesta quedan para el acuerdo con B.

## Pedido a B · Autorización auditada

Propuesta para revisión, probada con un doble:

- `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion`, con `Idempotency-Key` y cuerpo
  `{ "alcance": "resumen" }` o `{ "alcance": "exacta" }`. Devuelve
  `{ autorizacionId, venceEn }` sin descripción, coordenadas ni información de salud.
- La emisión comprueba actor, sesión, rol, asignación vigente, turno y cobertura aplicable.
  El alcance `exacta` exige `en_camino`. En la misma transacción se registra actor, fecha, caso y
  alcance en `emergencias.auditoria`, y se emite el permiso con el menor vencimiento aplicable.
- Tabla propuesta `emergencias.autorizaciones_stream` con `id`, `asignacion_id`, `sesion_id`,
  `alcance`, `vence_en` y `revocada_en`. PowerSync la usa para calcular permisos. Sus filas
  jamás son datos descargables. El barrido de B marca `finalizada_en` al vencer la asignación y
  `revocada_en` al vencer el permiso. También revoca al cerrar sesión, perder la habilitación o
  finalizar el acceso. Las reglas de PowerSync comprueban esas marcas y el estado del pedido.
- B mantiene `detalles_pedidos` fuera de la publicación en su entrega actual. Antes de activar la
  integración, revisar con B la proyección mínima que permite publicar `pedido_id`,
  `descripcion`, `lat` y `lng` para el stream exacto con estos controles. Verificar en vivo la
  lectura auditada, la revocación y la ausencia de filas sin permiso.

## Verificación

Las pruebas de acceso usan el evaluador de Sync Streams con filas ficticias. Las pruebas Flutter
inyectan los permisos y el transporte de sincronización y usan bases PowerSync cifradas de
verdad. Simulan el retiro de filas al reasignar entre dos cuentas, y verifican el estado en memoria
y el borrado de archivos y claves. Las pruebas de integración del backend verifican la firma del
`sid` de dos celulares de la misma cuenta con PostgreSQL y PostGIS.

| Comprobación | Extracto del resultado |
| --- | --- |
| `app/tool/verify.sh` | `No issues found!` · `+233 ~1: All tests passed!` · `✓ App verificada`. |
| `npm run verify` del backend | `45 passed (45)` archivos · `245 passed (245)` pruebas · compilación NestJS. |
| Evaluador de Sync Streams | `17 passed (17)` pruebas dirigidas, incluidas las del pedido propio. Configuración válida con cero advertencias. |
| `npm run test:integration` del backend | `24 passed (24)` archivos · `191 passed (191)` pruebas en PostgreSQL 18.6 con PostGIS. |
| CDN, OpenAPI y OpenSpec | `pass 10` en CDN · OpenAPI válido con tres advertencias previas · `27 passed, 0 failed` en OpenSpec. |

El lint del backend reportó seis advertencias previas en pruebas de directorio y reputación.

La prueba de Flutter con PowerSync en vivo requiere un pedido ficticio en `en_camino`, asignado
al operador de pruebas, la ruta auditada implementada y la publicación aprobada. Ejecutar
`integration_test/assigned_case_revocation_test.dart` con `TEST_ASSIGNED_CASE_ID` y `TEST_OTP`
solo en el entorno de laboratorio. La Parte 2 queda pendiente de esa verificación y del CI.
