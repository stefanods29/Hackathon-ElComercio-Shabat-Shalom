# Revisión técnica preliminar de las migraciones de B

8 de noviembre de 2026 · Base `4fb7761` de `main` · PostgreSQL 18.6 y PostGIS de laboratorio.
La revisión conjunta de B 5.3 corresponde a `Defartion` y `JDiazD33` y está pendiente.

## Hallazgo reproducido

`202611160100_emergencias_streams_operativos` rellena el historial del autor e instala
los tres disparadores. La ubicación de los pedidos se proyecta cuando se inserta o se
actualiza el pedido. Al migrar con un pedido ficticio que ya estaba `en_camino`, quedó un
detalle privado existente y cero ubicaciones proyectadas.

`202611160110_emergencias_relleno_ubicaciones` recupera la proyección de los casos abiertos,
vigentes y sin anonimizar que siguen `en_camino`. Conserva las filas que el disparador ya
escribió. La prueba comprueba el relleno, el reintento, la exclusión de pedidos vencidos y
la retirada de la copia al cambiar de estado.

## Comprobaciones de laboratorio

- Emergencias y migraciones pasaron 16 pruebas de integración. El recorrido por la API
  incluye cola minimizada, ubicación exacta en el estado permitido y auditoría de las
  lecturas sensibles.
- Con `powersync_rol` creado antes de migrar, se comprobó que puede leer
  `ubicaciones_en_camino`, que carece de permisos para escribir allí y que carece de
  `SELECT` sobre `detalles_pedidos`. La prueba de migraciones verifica también el conjunto
  de tablas que forman parte de la publicación.
- El guard resuelve el actor contra Identidad. El adaptador intersecta los roles del token
  con los persistidos y conserva el menor nivel de confianza.
- `202611090200_emergencias_operacion` copia el texto anterior a la tabla privada para los
  pedidos abiertos y sustituye `detalle` por un texto genérico. El índice único anterior
  limitaba a una asignación activa por pedido. El nuevo aplica el límite por pedido y rol.

## Puntos para la revisión conjunta

- Revisar los permisos y los 404 de cada ruta con usuarios de otras zonas, roles revocados
  y pedidos ajenos. Revisar las plantillas y los motivos que se devuelven al autor.
- Comprobar los privilegios efectivos de PowerSync y la retirada de copias con el servicio
  real, incluidas las sesiones que ya habían sincronizado antes de migrar.
- Aprobar y ensayar la reversión de `202611090100` y `202611090200`, cuyos `down()` se
  detienen por diseño. Para el ensayo, restaurar una copia previa aislada con la versión
  de API correspondiente y comprobar la publicación y las cachés antes de reanudar el
  servicio. El equipo debe acordar cómo conservar los cambios legítimos posteriores a la
  copia y cómo tratar los datos privados al restaurar.
- Registrar fecha, responsables y decisiones de la revisión conjunta y enlazar la CI
  del cambio antes de marcar B 5.3.
