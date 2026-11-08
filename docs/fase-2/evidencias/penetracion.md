# Prueba de penetración · A 5.1 y 5.3

Fecha: 8 de noviembre de 2026. Responsable: `JDiazD33`. Base auditada:
`4fb7761a52d2762911dbfb02ea5b7c9e25781d26` de `main`. Las pruebas de esta entrega
usan NestJS en proceso, PostgreSQL 18.6 con PostGIS 3.7 y Flutter 3.47.9 en macOS.
El ejercicio manual requiere una compilación candidata identificada por SHA y teléfonos de prueba.
Solo se usan cuentas y pedidos ficticios. Se conservan estados, códigos, conteos y versiones.

## API y sincronización

| Caso | Ejecución y control positivo | Resultado |
|---|---|---|
| API1, API3 · Pedidos de Emergencias | Abrir, cambiar estado, priorizar, asignar y pedir permiso con ID ajeno o sin autorización. Comparar 404 de un caso ajeno con un ID inexistente. Repetir como autor o persona asignada. Revisar columnas en cola, historial y auditoría. | HTTP local: el vecino y el coordinador sin asignación no abren ni cambian el pedido. La cola no lleva descripción ni coordenadas. El flujo autorizado permite abrir el caso. |
| API1, API5 · Eventos, habilitaciones, turnos, grupos y recursos | Cambiar ID de zona, evento, habilitación, turno, grupo o recurso según la ruta. Probar un vecino, un coordinador por debajo del nivel requerido y un rol presente solo en el JWT. En recursos, probar un vecino ajeno a la zona, otro del mismo barrio y la confirmación permitida. | HTTP local: 403 por rol/nivel y 404 al acceder a los recursos y lecturas de otra zona cubiertos por la prueba. El vecino de la misma zona sí puede confirmar un reporte ajeno. |
| API1, API5 · Notificaciones | Intentar listar y confirmar un aviso de otra cuenta, incluso con la clave usada por su destinatario. Consultar el resumen operativo sin rol. | HTTP local: solo el destinatario ve y confirma el aviso. La otra cuenta recibe 404 y el resumen operativo devuelve 403. |
| API1, API5, API8 · Curaduría | Listar, leer y escribir un archivo con un rol que solo figura en el token. Enviar una ruta de archivo inválida con un rol permitido. El alcance de curaduría es el directorio completo. | HTTP local: 401 sin token, 403 sin rol autorizado y 400 para el nombre de archivo inválido. |
| API2, API6 · Sesiones e idempotencia | Repetir la creación de pedido con la misma clave, cambiar el cuerpo y abrir un permiso con un token de otra sesión. Probar revocación y renovación con las pruebas de Identidad. | Un pedido persistido por ID. Cambio de cuerpo devuelve 422. Repetir un permiso con otra sesión reprodujo PEN-01. |
| API3, API5 · Suscripción directa | Probar stream automático, pedido ajeno, cuenta o sesión incorrecta, permiso ausente, alcance invertido, revocación y reasignación. Como control positivo, recibir el resumen o ubicación según la etapa y comprobar la retirada. | Las suites del evaluador de reglas devuelven **0 filas sensibles** en los casos no autorizados que cubren. |
| API4, API6, API10 · Límites y avisos | Revisar topes de SMS, reintentos y umbrales sin llamar a proveedores. Con un proxy comprobar la lista de destinos de una sesión, el transporte y la pantalla bloqueada. | Casos de API locales y SMS simulado disponibles. El recorrido de red y la recepción en teléfonos están pendientes. |
| API7, API8, API9 · Configuración e inventario | En el entorno candidato, cotejar rutas con los contratos, verificar destinos de la CDN y que el servidor nunca solicite URL arbitraria de curaduría. Revisar configuración TLS, CORS y ausencia de rutas de desarrollo y credenciales en la compilación. | Pendiente en el entorno candidato. |

Comandos desde `backend/` con Node 26 y una base local desechable. La variable
`DATABASE_URL_ADMIN` debe apuntar al servidor local de pruebas.

```sh
npm ci
npm run test:integration -- emergencies.int-spec.ts notifications.int-spec.ts sessions.int-spec.ts
npm test -- test/sync/datos-publicos.spec.ts src/modules/emergencias/sync-config-access.spec.ts
```

La [prueba en vivo de otra rama](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/blob/4c6602192dcc6726290e24d1bcd7fad6d710b492/docs/fase-2/evidencias/powersync-en-vivo.md)
reporta dos ejecuciones con PowerSync 1.28.1 y clientes SQLite separados. El resumen y la
ubicación solo llegaron a la sesión autorizada. Cuenta ajena, segunda sesión y permisos
invertidos dieron cero filas. Esa evidencia corresponde a clientes de laboratorio. Para el
cierre de A 5.1, repetir en los dispositivos con la versión candidata y confirmar el checkpoint
con un control positivo antes de registrar cada cero. Contar filas en cada una de las tablas
locales `pedidos_ayuda`, `ubicaciones_casos`, `mis_pedidos_ayuda` e `historial_mis_pedidos`
según cuenta y alcance. El historial del autor es una proyección autorizada.

## Recorrido manual OWASP MASVS

| Control | Procedimiento con Android e iOS | Aceptación |
|---|---|---|
| STORAGE-1/2 y CRYPTO-2 · Teléfono perdido | Cargar un caso ficticio en un equipo de prueba. Bloquear el modo operativo y aislar de la red. Intentar leer una copia del archivo, WAL, respaldos y registros sin la clave. Usar un marcador sintético y guardar solo conteos. | La base no abre sin clave y no hay texto del caso en copias auxiliares ni registros. Al vencer, volver a abrir sin señal y comprobar que el detalle se purgó. |
| NETWORK-1/2 · API y PowerSync | Usar el proxy de laboratorio en ambos sistemas con un control de certificado inválido. Probar carga de pedido, streams por sesión, curaduría, aviso bloqueado y reconexión. | La versión candidata rechaza certificados inválidos. Solo las rutas y destinatarios autorizados reciben las proyecciones previstas. Los avisos carecen de texto sensible. |
| PLATFORM-1/3 y AUTH-2 · Protección de la vista | Probar enlace directo con app bloqueada, cancelación de PIN/biometría, inactividad, cambio de cuenta y retorno a primer plano. Probar captura/grabación en Android y el selector de apps de iOS. | Detalle oculto antes de desbloquear y al volver de inactividad. Captura Android sin contenido y vista previa iOS ilegible. |
| RESILIENCE-1/2/4 · Manipulación | En equipos de laboratorio, cambiar el reloj y volver de segundo plano con permisos vencidos. Intentar acceso con permiso de otra sesión y observar en reconexión tras revocación. Registrar el alcance de dispositivos con integridad alterada. | Ninguna sesión gana acceso por cambiar el reloj o parámetros. Verificar por separado el vencimiento local, la revocación en línea y el riesgo del dispositivo desbloqueado y sin conexión. |

Fuentes de los controles. [OWASP MASVS](https://mas.owasp.org/MASVS/) ·
[OWASP API Security Top 10 2023](https://api-security.owasp.org/editions/2023/en/0x11-t10/).

Por caso manual anotar fecha, SHA de app/API, modelo y SO, alias de sesión, control positivo,
resultado y número de filas por tabla. Para capturas o proxy, guardar solo una descripción
redactada del resultado. El [riesgo del teléfono perdido](../criterios-de-salida.md#decisiones-y-riesgos)
requiere constancia del equipo.

## Hallazgos y estado

| ID | Severidad | Hallazgo | Estado |
|---|---|---|---|
| PEN-01 | Media | Reutilizar una clave de apertura desde otra sesión de la misma cuenta devuelve el identificador del permiso anterior. Las reglas rechazan su uso en la otra sesión. | Corregido y repetido localmente en una [repetición en `657370d`](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/blob/657370da4022cf27111fdb1ad09652c60abdb6ce/docs/fase-2/evidencias/penetracion-idempotencia-sesion.md). Falta integrar y repetir en el candidato. |
