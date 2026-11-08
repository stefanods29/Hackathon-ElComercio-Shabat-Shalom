# PEN-01 · Reutilización de un permiso desde otra sesión

- Fecha: 8 de noviembre de 2026. Base: `4fb7761a52d2762911dbfb02ea5b7c9e25781d26`.
- Severidad media. Afecta `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion`.
- Reproducción local con PostgreSQL y datos ficticios en `emergencies.int-spec.ts`. Abrir
  el resumen del caso asignado y repetir la misma clave y cuerpo desde otra sesión de la
  misma cuenta. Antes, la API devolvía HTTP 200 con el identificador de la primera sesión
  porque el caché de idempotencia distinguía cuentas, pero no sesiones.
- La prueba de las reglas de PowerSync confirma que la otra sesión recibe cero filas aunque
  conozca ese identificador. El fallo expone metadatos del permiso y presenta como válida
  una apertura que no puede sincronizar.
- La repetición desde la sesión original conserva HTTP 200, el mismo permiso y el indicador
  de reintento. Desde otra sesión con la misma clave devuelve 422, sin identificador. Las
  demás rutas conservan la idempotencia por cuenta. La primera apertura de una sesión debe
  usar su propia clave. Las claves de apertura guardadas antes del cambio también requieren
  una clave nueva si se reintentan después de desplegarlo.

Repetición local en PostgreSQL 18.6: el caso de regresión devolvió 200 antes de la
corrección y 422 después. Pasaron las ocho pruebas de la suite de Emergencias y
`npm run verify` con 246 pruebas y build.
