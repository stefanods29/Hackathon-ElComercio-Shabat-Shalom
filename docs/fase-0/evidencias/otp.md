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

## Resultados de verificación

- Node 26.13.0 y PostgreSQL 18.6 con PostGIS, usando una base temporal aislada.
- `npm run verify`: correcto; 53 pruebas unitarias en 11 archivos, lint sin advertencias, formato,
  fronteras, Sync Streams y compilación correctos.
- `npm run test:integration`: 33 pruebas en 5 archivos, incluidas concurrencia de solicitudes,
  consumo único del OTP y elección atómica de zona.
- Redocly: contrato válido; tres advertencias `operation-4xx-response` en rutas públicas (dos ya
  existentes y la lista de zonas), sin errores.
- `openspec validate --all --strict`: 10 elementos válidos y ninguno fallido.
- Tareas 1.1, 1.2, 1.3, 1.5 y 1.6 marcadas; 1.4 pendiente únicamente de la prueba manual real.
