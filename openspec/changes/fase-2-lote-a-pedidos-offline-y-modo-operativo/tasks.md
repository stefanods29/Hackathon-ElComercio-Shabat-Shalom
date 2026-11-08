# Tasks

## 1. Parte 1 · Pedidos de ayuda sin conexión

Las tareas 1.1–1.3 forman el primer incremento con datos ficticios. La integración operativa de 1.4–1.6 requiere el contrato de B1–B2 y una base acordada con D.

- [x] 1.1 Persistir en una transacción el pedido ficticio con UUIDv7, clave de idempotencia y estado local en la cola cifrada por cuenta. Verificar que el estado solo aparece tras confirmar la escritura, que el pedido sobrevive a reabrir la base y que guardar dos veces el mismo borrador conserva una sola entrada.
- [x] 1.2 Extender el envío de la cola para probar pedidos con un transporte ficticio y reloj controlado. Verificar en una matriz automatizada de 500 pedidos que las interrupciones y los reintentos dejan cero pérdidas y cero duplicados. Probar aparte un rechazo definitivo, la continuidad de la cola y la compatibilidad con comandos de solidaridad previos.
- [x] 1.3 Implementar la vista de estado e historial del pedido propio con fuentes ficticias en pruebas. Verificar en Flutter que el estado de envío depende del acuse y que un cierre o derivación de versión más reciente conserva su motivo. Registrar los resultados como evidencia de laboratorio.
- [ ] 1.4 Con el contrato de B1–B2 aprobado, conectar la carga a la ruta y los errores acordados, y configurar `mi_pedido` con pedido e historial filtrados por autor. Verificar la idempotencia con la API, cero filas para otra cuenta, ausencia de datos sensibles en streams automáticos y purga al salir de la cuenta.
- [ ] 1.5 Conectar el repositorio al puerto de D y validar en sus pantallas un pedido en modo avión, el mensaje de que nadie lo recibió, las alternativas oficiales y la reconciliación de un cierre o derivación al recuperar la señal. Verificar que el modo de práctica permanece aislado del flujo real.
- [x] 1.6 Compilar y depurar la parte. Ejecutar `tool/verify.sh` desde `app/`, las comprobaciones de Sync Streams del backend y `openspec validate --all --strict`. Verificar CI en verde y adjuntar el resultado. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).

**Integración en `main` (8 de noviembre de 2026).** La carga usa la ruta y los errores de B, `mi_pedido` lee la copia `emergencias.historial_para_autor` y el tablero de D usa este repositorio ([integración](../../../docs/fase-2/integracion.md)). Falta aprobar el contrato con el equipo, probar con PowerSync en vivo y en modo avión y ver la CI.

**Pendiente de verificar.** La [evidencia de laboratorio e integración local](../../../docs/fase-2/evidencias/pedidos-offline-laboratorio.md) cubre la cola, la purga, el acceso al stream con filas ficticias y la reconciliación. Para 1.4 falta aprobar y probar B con PowerSync y su API. Para 1.5 falta conectar el puerto de D y validar sus pantallas en modo avión. La CI de 1.6 quedó en verde con la versión integrada.

## 2. Parte 2 · Streams bajo demanda por asignación

Depende de las tablas y transiciones de B2–B3 y del mecanismo de auditoría de B5.

- [ ] 2.1 Extender el stream asignado con la ubicación aproximada y habilitar un flujo separado para ubicación exacta durante «En camino». Verificar en PowerSync cero filas sin asignación activa, cero filas exactas antes del estado permitido y retirada de la ubicación al terminarlo.
- [ ] 2.2 Integrar la autorización auditada de la apertura con B. Verificar que el backend registra actor, fecha y caso, y que una suscripción directa fuera de ese flujo no puede obtener el detalle.
- [ ] 2.3 Actualizar el caché del caso para la revocación y el cierre. Verificar reasignación con dos cuentas y purga en la siguiente sincronización, incluidos el detalle en memoria y la ubicación exacta.
- [ ] 2.4 Compilar y depurar los cambios de app y backend. Ejecutar `npm run verify`, las pruebas de integración con PowerSync y `tool/verify.sh` desde `app/`. Verificar CI en verde.

**Integración en `main` (8 de noviembre de 2026).** B implementa `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion`, la tabla `autorizaciones_stream` con su revocación al terminar la asignación y la copia `ubicaciones_en_camino`; la prueba de integración del backend lo recorre con PostgreSQL. Falta PowerSync en vivo con dos cuentas.

**Pendiente de verificar.** El [informe de laboratorio](../../../docs/fase-2/evidencias/streams-por-asignacion.md) registra el evaluador de Sync Streams, la sesión firmada y la purga local con dos cuentas ficticias. Para 2.1–2.3 falta el acuerdo de B y la prueba de autorización, retiro y reasignación con PowerSync en vivo. Para 2.4 queda pendiente registrar el CI del commit de entrega.

## 3. Parte 3 · Modo operativo protegido

El bloqueo y la caducidad pueden probarse inicialmente con casos ficticios y reloj controlado.

- [x] 3.1 Implementar el bloqueo local con PIN o biometría y el cierre por inactividad. Verificar con pruebas unitarias y de widgets la cancelación, el límite de inactividad y la reapertura sin red.
- [ ] 3.2 Aplicar `FLAG_SECURE` en Android y la vista difuminada en el selector de apps de iOS. Verificar en ambos sistemas con teléfonos reales que el contenido sensible no queda visible y registrar el resultado en `docs/fase-2/evidencias/modo-operativo.md`.

  Preparación Android: [guía y pasos esperados](../../../docs/fase-2/evidencias/telefonos-android.md) y [registro de teléfonos reales](../../../docs/fase-2/evidencias/modo-operativo.md#teléfonos-reales). Sigue abierta: POCO X6 Pro con Android 16 conectado, pero falta el caso ficticio autorizado en la API local y las observaciones de protección por `JDiazD33`; iPhone no se ejecutó por no disponer de Mac, Xcode ni herramientas de firma. Alcance actual limitado a Android por indicación del responsable.
- [x] 3.3 Aplicar caducidad y purga al cerrar el caso, al reabrir la app y al volver a primer plano. Verificar con reloj de prueba y modo avión que un caso vencido se purga antes de mostrarse y que el autor conserva solo su historial mínimo permitido.
- [x] 3.4 Compilar y depurar la app con `tool/verify.sh` desde `app/`. Verificar CI en verde con compilaciones de Android e iOS. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).

El [informe de la Parte 3](../../../docs/fase-2/evidencias/modo-operativo.md) registra la verificación de 3.1 y 3.3 con reloj controlado y sin red en laboratorio. Para 3.2 quedan pendientes las pruebas de capturas y del selector en teléfonos reales. La CI de 3.4 quedó en verde con Android e iOS en la versión integrada.

## 4. Parte 4 · Tablero sin conexión

Depende de agregados y recursos de B4, del tablero de D y del directorio curado cuando C lo publique.

- [x] 4.1 Configurar los streams públicos de agregados y recursos por zona. Verificar con datos sembrados de B que no se replica el grupo de dos pedidos, que el de tres llega solo como agregado y que el stream no incluye detalle ni filas de otra zona.
- [ ] 4.2 Conectar frescura y fuentes al tablero de D. Verificar con reloj de prueba y modo avión los límites por tipo, la indicación de datos antiguos y la fuente de recursos oficiales.
- [x] 4.3 Priorizar los datos críticos y desactivar las imágenes en modo emergencia. Verificar la prioridad configurada y la ausencia de solicitudes de imágenes al recuperar señal con tráfico pendiente.
- [x] 4.4 Compilar y depurar app y configuración de sincronización. Ejecutar `npm run verify` en backend y `tool/verify.sh` desde `app/`. Verificar CI en verde. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).

En la integración B publica `verificado_en` y el tablero de D muestra los recursos del stream con su fuente verificada; falta la verificación con reloj de prueba y modo avión de 4.2. El [informe de la Parte 4](../../../docs/fase-2/evidencias/tablero-offline.md) registra la verificación de 4.1 con el SQL de B y de 4.3 con el evaluador de streams y la cola de fotos en reconexión. Para 4.2 falta conectar el tablero de D y recibir la fecha de verificación oficial de B. La CI de 4.4 quedó en verde con la versión integrada.

## 5. Parte 5 · Seguridad y pruebas de campo

- [ ] 5.1 Ejecutar la prueba de penetración sobre la app y la API según OWASP MASVS y OWASP API Security Top 10. Registrar en `docs/fase-2/evidencias/penetracion.md` los casos ejecutados, la versión, los hallazgos y la evidencia de cero filas sensibles en dispositivos sin autorización.
- [ ] 5.2 Ejecutar la prueba de campo con reconexiones simultáneas, señal débil, batería baja y pedidos ficticios. Registrar en `docs/fase-2/evidencias/modo-operativo.md` los dispositivos, condiciones, versión y conteo de pérdidas o duplicados.
- [ ] 5.3 Corregir los hallazgos del lote y volver a probarlos. Compilar y depurar con `npm run verify` y `tool/verify.sh` desde `app/` según lo tocado. Verificar CI en verde y enlazar la evidencia de repetición.

## 6. Parte 6 · Integración y simulacro

Requiere las entregas aprobadas de B, C y D, la evaluación de impacto, cobertura y tiempos acordados con los aliados, y autorización del equipo para integrar.

- [ ] 6.1 Preparar la integración aprobada y comprobar el flujo completo desde un pedido en modo avión hasta su asignación y cierre. Verificar contratos, versión integrada y cobertura operativa en el entorno acordado.
- [ ] 6.2 Realizar el simulacro con los aliados y registrar en `docs/fase-2/evidencias/simulacro.md` pedidos de cada prioridad, escalamiento, avisos, cierre y resultado de pérdidas y duplicados. Verificar que los vecinos identifican el estado y las alternativas oficiales.
- [ ] 6.3 Hacer la revisión sin culpables con el equipo, registrar hallazgos en `docs/fase-2/evidencias/revision-simulacro.md` y actualizar los criterios de salida con sus evidencias y decisiones pendientes.
- [ ] 6.4 Compilar y depurar la versión integrada. Ejecutar las verificaciones documentadas de app, backend, consola, contrato y OpenSpec, y comprobar CI en verde para la versión del simulacro.

## Workflow follow-up

- Archivar el cambio una vez aprobada la última entrega, comprobado el CI y registrados los criterios de salida.
- Verificar el resultado archivado con `openspec validate --all --strict`.
