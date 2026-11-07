# Cuenta real y pantallas conectadas al núcleo offline

Fecha: 7 de noviembre de 2026. Rama: `fase0-a`.

## Alcance integrado

Se incorporaron las partes 1 y 2 del Lote B (OTP y sesiones renovables) y las pantallas
disponibles en la parte 5 del Lote D. El arranque normal usa `AuthenticatedApp` y
`HttpAuthRepository`; `DEV_SYNC=true` conserva la sesión de desarrollo anterior.

- Los tokens de acceso y renovación se guardan juntos en `SecureStore`.
- Veinte solicitudes simultáneas de token producen una sola renovación. Ante una
  revocación, se deja de entregar el token y se purga sin bloquear la petición de credenciales.
- La elección de zona conserva su clave de idempotencia al reintentar, incluso tras reiniciar.
- Cada cuenta tiene su propia base cifrada y caché de casos. Un cierre interrumpido se
  termina antes de restaurar otra sesión.
- El cierre local funciona sin API. «Perdí mi teléfono» exige confirmar la revocación
  global con el servidor y muestra un error si no se puede completar.
- Las pantallas usan `PowerSyncPostRepository`. El modo práctica usa un repositorio
  aislado y no agrega comandos a la base real.
- Los rechazos conservan el motivo y una alternativa aunque la publicación ya no esté
  disponible en el muro descargado.

## Comprobaciones locales

| Comprobación | Resultado |
| --- | --- |
| Sesión con HTTP falso | 10 de 10 aprobadas |
| Suite de la app con `LIVE_POWERSYNC=true` | 64 de 64 aprobadas, incluida la prueba contra la API y PowerSync locales |
| Análisis estático de la app | Sin incidencias |
| Pruebas unitarias del backend | 68 de 68 aprobadas |
| Integración del backend con PostgreSQL | 59 de 59 aprobadas |
| OpenSpec estricto | 10 de 10 elementos válidos |
| Contrato OpenAPI | 1 de 1 contrato válido; 3 advertencias sobre respuestas 4xx de consultas públicas |
| Recorrido integrado en Redmi Note 13, Android 15 | 1 de 1 aprobado en 22 segundos |

La prueba del Redmi está en `app/integration_test/authenticated_flow_test.dart`.
Solicita previamente un OTP con el proveedor `fake`, usa `TEST_OTP` al ejecutarla y
expone la API y PowerSync al dispositivo mediante los puertos USB 3000 y 8080.
El código de prueba no se guarda en el repositorio.

En el Redmi se verificó: código OTP real del proveedor fake → descarga del muro por
PowerSync → cierre de la app → reapertura con la API inaccesible → consulta del muro
descargado → publicación mediante el formulario → «Guardado en tu celular» → cierre
desde Mi cuenta sin API. Al terminar no quedaban el token, la marca de purga ni archivos
en el directorio cifrado de esa cuenta de prueba. Se usó el almacenamiento seguro de
Android con un prefijo aislado, sin reemplazar la sesión normal de la instalación.

## Límites para cerrar el lote

La baja del token de notificaciones depende del Lote C, todavía sin implementación
integrada. También faltan su aviso y mapa offline en el recorrido completo, la matriz
adversa de Android y las mediciones de segundo plano. Estas dependencias mantienen
abiertas las tareas correspondientes; esta integración no equivale al cierre de la Fase 0.

El usuario indicó que solo dispone del Redmi y autorizó omitir la prueba de campo en
iPhone. Se registra como **omitida por disponibilidad**, sin presentarla como aprobada
ni sustituirla por una compilación. La compilación de iOS se verifica por separado en CI.
