# Purga de casos asignados

- Fecha · 7 de noviembre de 2026.
- Dispositivo · Redmi Note 13, Android 15, conectado por USB a la API y PowerSync locales.
- App · Compilación de depuración, commit `c322b0c716c35161578361b75a4f87d4b26ea548`.
- Datos · Un caso sintético y dos cuentas de prueba. Se retiró el caso al terminar.

## Caducidad sin conexión

1. La cuenta de prueba con rol de coordinación abrió el caso por `caso_asignado`.
2. Se cerró la base y se volvió a abrir con un reloj de prueba en `vence_en` y un conector sin red.
3. La app devolvió el detalle como ausente y se comprobó que el archivo y su clave ya no existían.
   El conector registró cero solicitudes.

Una prueba automatizada adicional confirmó que se conservan el archivo, la clave y las
acciones pendientes de la base del muro.

## Reasignación con conexión

1. Se descargó otra vez el mismo caso sintético con la asignación original.
2. PostgreSQL cerró la asignación y asignó el caso a una cuenta de prueba con rol de brigadista.
3. PowerSync aplicó el cambio en el Redmi. El detalle desapareció y se verificó el borrado
   del archivo SQLite del caso y de su clave en el almacén seguro de Android.

Las comprobaciones se ejecutaron con `integration_test/assigned_case_revocation_test.dart`.

## Cierre local de la sesión de prueba

En el emulador Android 36, con el commit `8a6b76ce90da1abfa2a5b4ee7505880c50728ebf`,
la app inició con una publicación sintética pendiente y un caso sintético guardado. Al
cancelar el cierre, conservó la publicación. Al confirmar sin conexión, eliminó ambos
archivos SQLite y sus claves, volvió a «Iniciar sesión de prueba» y mantuvo ese estado
al volver a abrirse.

La segunda prueba dejó los archivos presentes con una marca de cierre persistida. Al iniciar,
la app terminó la purga antes de mostrar el inicio. Ambas pruebas pasaron con
`integration_test/demo_sign_out_test.dart`. La conexión con la pantalla de cuenta y la
revocación en la API siguen pendientes.
