# Evidencia de OTP

Fecha: 2026-11-07 · Rama: `lote-b/parte-1-otp` · Estado de entrega: **En curso, pendiente de revisión**.

## Prueba manual con Twilio

**Pendiente.** No se dispone en este entorno de credenciales Twilio ni de un teléfono autorizado para
recibir el mensaje. No se realizó ni se simuló una prueba manual y la tarea 1.4 permanece sin marcar.

Cuando el equipo disponga de acceso, la prueba debe configurar las credenciales únicamente en `.env`,
elegir `OTP_PROVIDER=twilio`, solicitar un OTP por SMS y otro por WhatsApp, verificar el código recibido
y comprobar que un fallo del proveedor responde 503. No se deben copiar códigos, tokens ni credenciales
a este documento ni a los logs.

## Cobertura automatizada

`twilio-otp.provider.spec.ts` sustituye `fetch` por un doble y comprueba la URL, autenticación básica,
cuerpo formulario, prefijos de WhatsApp, texto del mensaje y conversión de errores HTTP y de red a 503.
Las pruebas automatizadas no establecen conexiones con Twilio ni envían SMS reales.

## Verificación de la entrega inicial (`49e31ad`)

- Node 26.13.0 y PostgreSQL 18.6 con PostGIS, usando una base temporal aislada.
- `npm run verify`: correcto; 53 pruebas unitarias en 11 archivos, lint sin advertencias, formato,
  fronteras, Sync Streams y compilación correctos.
- `npm run test:integration`: 33 pruebas en 5 archivos, incluidas concurrencia de solicitudes,
  consumo único del OTP y elección atómica de zona.
- Redocly: contrato válido; tres advertencias `operation-4xx-response` en rutas públicas (dos ya
  existentes y la lista de zonas), sin errores.
- `openspec validate --all --strict`: 10 elementos válidos y ninguno fallido.
- Tareas 1.1, 1.2, 1.3, 1.5 y 1.6 marcadas; 1.4 pendiente únicamente de la prueba manual real.

## Corrección tras revisión

Se corrigieron el reinicio de los intentos al reenviar un código y la ausencia de límites por IP
en las verificaciones. La migración adicional `202611070110_identidad_limites_otp.ts` crea
estado privado por teléfono e IP en `identidad.limites_otp`, separado de los códigos y excluido
de PowerSync. Antes de ejecutar esta versión sobre una base existente, aplicar `npm run db:migrate`.

- `OTP_MAX_ATTEMPTS_PER_IP`: nueva variable opcional, 20 por defecto. Los fallos se acumulan
  en una ventana de `OTP_LOCK_MINUTES` entre todos los teléfonos de esa IP.
- Cada bloqueo dura `OTP_LOCK_MINUTES` desde el fallo que alcanza el límite. Las solicitudes
  rechazadas no prolongan el bloqueo.
- Los reenvíos conservan los fallos del teléfono. La caducidad del OTP y reiniciar la API no
  borran el bloqueo. Un acceso válido reinicia únicamente el contador del teléfono.
- Se normalizan las IP antes de serializar y contar; la concurrencia no permite superar
  el límite con distintas representaciones de la misma IPv6.

Verificación con Node 26.13.0 y PostgreSQL 18.6 + PostGIS 3.7:

- `npm run verify`: correcto; **56 pruebas unitarias en 12 archivos**, tipos, lint sin avisos,
  formato, fronteras, Sync Streams y build.
- `npm run test:integration`: **39 pruebas correctas en 6 archivos**.
- OpenSpec estricto: 10 elementos válidos; contrato OpenAPI válido con las mismas tres
  advertencias documentadas. Grafo regenerado, fronteras y `git diff --check` correctos.
- Las seis pruebas de `otp-abuse.int-spec.ts` fallaron sobre la entrega inicial y pasaron
  tras corregirla. Cubren fallos entre reenvíos, bloqueo desde el quinto fallo, caducidad,
  reinicio, fin del bloqueo, IP compartida entre teléfonos, acceso válido que no borra fallos IP,
  solicitudes concurrentes, códigos inexistentes y equivalencias IPv6.
- Tres pruebas unitarias adicionales verifican la duración, el tiempo restante y el reinicio
  de la ventana.

La prueba manual con Twilio sigue pendiente y la tarea 1.4 permanece abierta. La entrega se
conserva en `lote-b/parte-1-otp`, únicamente mediante commit y push, sin declarar CI ni crear PR.
