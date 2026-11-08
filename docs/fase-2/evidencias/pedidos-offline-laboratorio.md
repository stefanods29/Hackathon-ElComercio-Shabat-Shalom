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
