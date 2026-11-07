# Evidencia de OTP

Fecha: 2026-11-07 · Ramas: `lote-b/parte-1-otp` y `revision/cierre-fase-0`.

## Proveedor real: Firebase Authentication (tarea 1.4)

El 7 de noviembre de 2026 el equipo eligió Firebase Authentication como proveedor real
([ADR 0009](../../adr/0009-proveedor-de-codigos-firebase.md)). Con `OTP_PROVIDER=firebase`:

- Firebase envía y comprueba el SMS en el celular.
- La API valida el ID token en `POST /v1/auth/firebase` y entrega la sesión de siempre.

El adaptador falso sigue siendo el de desarrollo y pruebas. El de Twilio queda disponible si el
equipo cambia de proveedor.

### Cobertura automatizada

| Prueba | Qué demuestra |
| --- | --- |
| `src/modules/identidad/application/sign-in-with-firebase.spec.ts` (4) | Sesión para el teléfono confirmado. Reutiliza al vecino existente. Un token inválido o de hace más de 10 minutos no crea cuentas. |
| `src/modules/identidad/infrastructure/firebase-phone-token.verifier.spec.ts` (6) | Solo acepta ingresos por teléfono con número internacional. Un token vencido o de otro proyecto es inválido. Si no se pueden consultar las claves de Google responde 503, y sin proyecto, `metodo_no_disponible`. |
| `test/integration/firebase-auth.int-spec.ts` (5) | Con PostgreSQL: crea la sesión con `refreshToken` y la cuenta una sola vez, responde 401 `token_firebase_invalido` y 409 en las rutas de código con Firebase activo o sin `FIREBASE_PROJECT_ID`. |
| `app/test/features/cuenta/http_auth_repository_test.dart` (3 nuevas) | La API solo recibe el token. Un token rechazado se muestra como código vencido. La verificación automática y el código escrito abren una sola sesión. |

Verificación del 7 de noviembre de 2026:
- `npm run verify`: 161 pruebas unitarias.
- `npm run test:integration`: 114 pruebas en 14 archivos.
- Redocly: válido, con las tres advertencias ya documentadas.

### Prueba manual en Android

**Pendiente de registrar.** Se hará en un Redmi Note 13 con un número real de Perú, siguiendo
`app/README.md` (sección «Ingresar con SMS reales») y el proyecto Firebase del equipo, que solo
permite números de Perú. No se copian números, códigos ni tokens a este documento.

## Prueba manual con Twilio (descartada)

No se dispone de credenciales Twilio de pago. Con la elección de Firebase, esta prueba ya no es
necesaria para cerrar la tarea 1.4.

Si el equipo vuelve a Twilio, la prueba debe configurar las credenciales únicamente en `.env`,
elegir `OTP_PROVIDER=twilio`, solicitar un OTP por SMS y otro por WhatsApp, verificar el código recibido
y comprobar que un fallo del proveedor responde 503. No se deben copiar códigos, tokens ni credenciales
a este documento ni a los logs.

## Cobertura automatizada de Twilio

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
