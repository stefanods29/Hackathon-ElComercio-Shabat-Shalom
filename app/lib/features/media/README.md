# Fotos privadas · Fase 1 C

`/fotos` permite escoger una imagen, preparar un borrador y consultar su estado. La entrada
está en el muro cuando se compila con `--dart-define=ENABLE_PHOTOS=true`. No requiere Firebase
para seleccionar y conservar fotos locales.

El selector nativo usa la galería, recupera una selección interrumpida en Android al volver a
abrirlo, limita el original a 15 MiB/20 megapíxeles y prepara JPEG ≤1280 px, calidad 75, sin EXIF,
máximo 2 MiB. Cancelar no crea una foto. El servidor vuelve a verificar y sanear todo.

## Organización

- `domain`: estado local y puertos sin dependencias de Flutter.
- `application`: cola persistente, reintentos y baja; no depende de plugins.
- `data`: API, galería, cifrado, transferencia nativa y composición de Riverpod.
- `presentation`: galería accesible, vista previa local, selector reutilizable y foto pública.

Metadatos y claves permanecen en almacenamiento seguro; las fotos usan AES-GCM de 256 bits
con clave por cuenta y datos autenticados de dueño/archivo. La escritura es atómica. Una
alteración del archivo se rechaza al descifrar. La copia temporal para el cargador nativo vive
en almacenamiento privado, se elimina al terminar/cancelar y se recupera su limpieza al arrancar.
La foto original de la galería del vecino nunca se borra.

## Integración con A

`mediaCredentialsProvider` devuelve `null` por defecto. A debe conectarlo a su sesión real con
`MediaCredentials(userId: uuid, accessToken: jwt)`. El API valida el token vigente en cada
petición, incluso después de renovarlo. Nunca conectar aquí la identidad de demostración.
Sin credenciales las fotos se conservan localmente y la pantalla lo explica.

Antes de limpiar o cambiar la sesión, A debe esperar:

```dart
await ref.read(photoControllerProvider.notifier).signOut();
```

Eso cancela tareas de esa cuenta y purga su bóveda aun si falla la cancelación nativa. El
cambio de cuenta también impide enviar con credenciales de otra persona. No migrar borradores
demo automáticamente a una cuenta real ni conservar los de la persona anterior.

`PhotoRuntime` mantiene la cola mientras la aplicación está abierta y consulta al recuperar
conexión, volver al primer plano o cada 30 segundos. `background_downloader` ejecuta el PUT
nativo ya iniciado; crear, renovar firmas y confirmar requieren que la app vuelva a ejecutarse.
El sistema puede suspender tareas: la interfaz nunca promete entrega inmediata.
La respuesta de confirmación perdida se reconcilia consultando estado, sin volver a subir bytes.

Configurar `API_BASE_URL` y `MEDIA_STORAGE_ORIGIN`. Este último debe coincidir exactamente con
el origen firmado por el backend. Solo se admite HTTPS, salvo localhost/10.0.2.2 en desarrollo.
No se guardan las firmas. Para configurar almacenamiento local, ver `infra/media/README.md`.

## Integración con B/D

`PhotoAttachmentPicker(selectedIds: ..., onChanged: ..., maximum: 3)` muestra miniaturas listas
y devuelve IDs, nunca URLs. D lo inserta en sus formularios; B valida dueño, estado y reglas
del contenido padre mediante la interfaz pública de Media. Elegir una foto no la publica.
`PublicPhoto` sirve para derivados que B haya autorizado como públicos: exige HTTPS sin firmas
en la consulta y admite blurhash. La caché persistente de fotos públicas queda pendiente de la
política de sincronización de A/B; las vistas previas propias sí funcionan sin red.

Pruebas: `flutter analyze` y `flutter test`. La selección real, suspensión, reinicio del proceso,
cambio de cuenta y cierre de sesión deben verificarse en Android/iOS antes de aprobar el piloto.
