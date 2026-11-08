# Pedidos de ayuda sin conexión · Laboratorio

El 8 de noviembre de 2026 se probó el código de `c82ad95c5946fd22f208b57de8ebcc35c24ae473`
con Flutter 3.47.9 en macOS. Las pruebas usaron una base PowerSync cifrada por cuenta, un almacén
de claves en memoria para pruebas, un reloj controlado y respuestas HTTP ficticias.

| Caso | Resultado |
|---|---|
| Guardar el mismo borrador dos veces en paralelo y reabrir la base | Un comando pendiente. El UUIDv7, la clave de idempotencia y el estado local se conservaron. |
| Drenar una cola de 500 pedidos con cortes simulados antes de recibirlos y después de guardarlos, pero antes del acuse | 500 pedidos confirmados, 0 perdidos y 0 duplicados. Se reabrió la base al comenzar el drenaje y después de un corte de cada tipo. |
| Acuse con un identificador distinto y rechazo por falta de cobertura | El acuse incorrecto dejó el pedido pendiente. El rechazo quedó visible para Emergencias y la cola procesó el siguiente comando de Solidaridad. |
| Cierre o derivación durante la desconexión | El modelo del pedido propio conservó el motivo y el siguiente paso de la versión confirmada. Excluyó las filas del pedido ajeno incluidas en la prueba. |

### Verificación local

- Pasaron las 13 pruebas dirigidas de pedidos, conector y pantallas de Solidaridad. El análisis de Flutter no reportó problemas.
- La suite completa de Flutter dio 110 pruebas aprobadas, una omitida por requerir PowerSync en vivo y un fallo en `account_flow_test.dart:87`. Ese fallo se reprodujo con los mismos pasos en una copia limpia de la base `d051f0a`.
- El formato pasó en los nueve archivos Dart de la entrega. La comprobación de formato de toda la app señaló `api_push_registration.dart`, cuyo contenido coincide con la base.
- La validación estricta de OpenSpec aprobó las 22 comprobaciones.

### Pendientes de integración

La evidencia corresponde a las tareas 1.1–1.3. Para 1.4–1.6 faltan la aprobación del contrato de B,
la conexión con las pantallas de D, las pruebas con la API y PowerSync y la verificación en CI.
La entrega de B `0a69b19` figura sin compilar ni probar. Propone leer el detalle exacto por una
API auditada y deja pendiente el contrato de los streams de A. A y B deben acordar ese punto
antes de implementar la Parte 2. Las pruebas de campo y el simulacro siguen pendientes.

## Preparación para integrar la Parte 1

El 8 de noviembre de 2026 se incorporó la Fase 1 integrada en `cace84e` a la rama de la Parte 1.
La cola compartida usa el UUIDv7 y la clave del borrador. Conserva el nombre persistido
`helpRequest` para poder leer entradas anteriores. La app envía a `POST /v1/pedidos-ayuda` con la
forma estricta de B en `0a69b19`. Un 2xx solo confirma el envío si devuelve el mismo ID. Un 4xx
definitivo conserva un código permitido y la UI muestra una explicación localizada.

El cuerpo del pedido queda en la cola de la base cifrada de la cuenta. Al completar la transacción
de subida, la cola retira el comando. Si el proceso termina entre registrar el acuse y completar
la transacción, la cola retira el comando al reanudar el drenaje sin enviarlo de nuevo. El repositorio
observa los pedidos de esa cuenta desde la sesión autenticada. Al recibir un cierre conserva solo
el estado final, versión, fecha y motivo apto para el autor, y retira la suscripción. El cierre de
sesión elimina la base, sus archivos auxiliares y su clave.

### Verificación local del incremento

| Comprobación | Extracto del resultado |
| --- | --- |
| `app/tool/verify.sh` | `No issues found!` · `+226 ~1: All tests passed!` · `Formatted 198 files (0 changed)` · `✓ App verificada` |
| Matriz Flutter con HTTP ficticio | 500 pedidos confirmados, 0 pérdidas, 0 duplicados. Se probaron 200, 201, 409, 422, cierre con reintento pendiente y purga al salir. |
| `npm run verify` en backend | `45 passed (45)` archivos · `242 passed (242)` pruebas · compilación NestJS completada. |
| `npm run sync:validate` y pruebas de acceso | `sync-config.yaml es válido (0 advertencia(s))` · 12 pruebas de datos públicos y del pedido propio. Otra cuenta recibió cero filas en el evaluador con datos ficticios. |
| `npm run test:integration` en backend | `24 passed (24)` archivos · `190 passed (190)` pruebas con PostgreSQL 18.6 y PostGIS de la base de Fase 1. |
| `npm test` en `infra/cdn` | `tests 10` · `pass 10` · `fail 0`. |
| Lint de OpenAPI | `Your API description is valid` · tres advertencias existentes de respuestas 4xx. |
| OpenSpec estricto | `Totals: 27 passed, 0 failed (27 items)`. |

La prueba de Flutter omitida exige PowerSync en vivo. El lint del backend reportó seis
advertencias existentes sobre ordenamientos en pruebas de directorio y reputación. Las
compilaciones móviles nativas quedan pendientes. El diagnóstico de Flutter señaló que faltan
el SDK de Android y CocoaPods.

### Dependencias para cerrar 1.4–1.6

- **B.** Aprobar y probar el contrato B1–B2. Acordar `emergencias.historial_pedidos.motivo_para_autor`
  con un motivo revisado o generado por el servidor para cada cierre o derivación. Publicar y
  conceder a PowerSync acceso solo a las columnas necesarias del historial propio, excluyendo
  `motivo` operativo y `usuario_id`. Las pruebas usan una fila ficticia con la columna propuesta.
  Verificar el stream y la idempotencia contra la API y la publicación reales antes de activar
  la integración. Los plazos del pedido los determina B al aceptar el comando.
- **D.** Conectar `operationalEmergencyFactoryProvider` al repositorio de la cuenta y obtener el
  evento y la cobertura verificada de `GET /v1/zonas/{zonaId}/cobertura`. El borrador de D en
  `1dd4388` necesita entregar `exactLocation` y `lifeThreatening` al flujo real. Su vista de
  pedido debe aceptar un resumen sin descripción ni coordenadas después del acuse. Validar
  el flujo completo en sus pantallas, en modo avión y al reconectar, con la práctica aislada.
- **CI.** Los workflows de app, backend y especificaciones no se disparan con un push a la rama
  de entrega. Queda pendiente registrar una ejecución del commit final.
