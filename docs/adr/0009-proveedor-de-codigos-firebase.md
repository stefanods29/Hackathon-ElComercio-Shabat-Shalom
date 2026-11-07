# 0009 · Firebase Authentication envía y comprueba los códigos por SMS

**Estado:** aprobado el 7 de noviembre de 2026, al cerrar la Fase 0.
**Dueño:** Lote B · tarea 1.4, con la integración en la app del Lote A.
**Alcance:** decisión abierta 4 de la sección 13.3 de la arquitectura y `identidad/inicio-de-sesion`
de OpenSpec.

## Contexto

La API ya tenía un puerto de envío de códigos con un adaptador falso, usado en desarrollo y en las
pruebas, y uno de Twilio por SMS y WhatsApp. Faltaba elegir el proveedor real y comprobarlo con
números reales antes de cerrar la Fase 0.

- La cuenta de prueba de Twilio no permite textos propios y su API no es accesible desde los
  entornos del equipo. Habría que pagar antes de la primera prueba real.
- El proyecto Firebase del equipo ya tiene el plan Blaze con el crédito de prueba de Google Cloud
  y una alerta de presupuesto. El ingreso por teléfono se puede limitar a números de Perú.

## Opciones

1. **Twilio (SMS y WhatsApp) desde la API.** Se conserva el adaptador. Requiere una cuenta pagada
   y guardar credenciales en el servidor.
2. **Twilio Verify.** Delega la generación y la comprobación del código, pero tiene el mismo
   requisito de cuenta pagada.
3. **Firebase Authentication en el celular.** Firebase envía el SMS y lo comprueba, y verifica que
   la solicitud viene de la app (Play Integrity o reCAPTCHA). La API solo valida el ID token de
   Firebase, con el ID del proyecto y sin secretos.

## Decisión

Se adopta la opción 3, configurable con `OTP_PROVIDER=firebase`:

- **App.** Con `PHONE_AUTH=firebase`, `FirebasePhoneVerifier` envía y comprueba el código con
  Firebase. Obtiene el ID token y cierra la sesión de Firebase de inmediato; `HttpAuthRepository`
  lo cambia por la sesión de la API. Las opciones de Firebase llegan por `--dart-define` y no se
  sube ningún archivo del proyecto. Si Android verifica el número por su cuenta, la app entra sin
  que el vecino escriba el código. Un código escrito que coincide con esa verificación no abre una
  segunda sesión.
- **API.** `POST /v1/auth/firebase` acepta solo tokens del proyecto configurado
  (`FIREBASE_PROJECT_ID`), emitidos por un ingreso con teléfono hace menos de 10 minutos. Entrega la
  misma sesión renovable que el código propio y crea el usuario con nivel 0 si no existía. Con este
  proveedor, `/v1/auth/otp` y `/v1/auth/otp/verificar` responden 409 `metodo_no_disponible`.
- **Proyecto.**
  - La consola registra las huellas SHA-1 y SHA-256 de cada clave de firma.
  - La política de regiones del SMS permite solo Perú.
  - La alerta de presupuesto queda activa.
- **Desarrollo y pruebas.** Se mantienen el adaptador falso y el de Twilio, por si el equipo
  cambia de proveedor. Ninguna prueba automatizada envía SMS reales.

## Consecuencias

- La API no guarda credenciales de SMS. El costo de cada SMS lo factura Firebase al proyecto.
- Los límites de intentos del código los aplica Firebase. Los límites propios de la API
  (`identidad.limites_otp`) siguen vigentes para el proveedor falso y para Twilio.
- Cada persona que compile para un celular debe registrar la huella de su clave de depuración. Las
  betas y la versión publicada usarán las huellas de la clave de firma del Lote C (Fase 1, parte 4).
- Firebase verifica primero la app con Play Integrity. Solo una app instalada desde Google Play la
  supera. Si falla (instalación por cable, celulares sin Google Play), abre una página de reCAPTCHA
  en el navegador que tenga el celular (Chrome, Samsung Internet, Firefox u otro) y vuelve a la
  app con el resultado. Para que esa vuelta funcione, `MainActivity` no lleva
  `android:taskAffinity=""`. Con esa línea de la plantilla de Flutter, el resultado se perdía
  («web operation canceled») y no se enviaba el SMS.
- iOS necesita la clave APNs o el respaldo con reCAPTCHA de Firebase, que se configurará cuando el
  equipo tenga un iPhone para el piloto.
- La evidencia de la prueba manual está en `docs/fase-0/evidencias/otp.md`.
