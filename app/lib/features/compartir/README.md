# Compartir publicaciones

El botón de compartir del muro utiliza el selector nativo de Android/iOS (`share_plus`).
WhatsApp aparece cuando está instalado y el sistema lo ofrece. No se envían mensajes desde el
backend ni se necesita Firebase para abrir este selector. SMS de autenticación corresponde a B.

Solo admite publicaciones confirmadas (`SubmissionStatus.sent`) con UUID válido. Comparte un
texto genérico y `/publicaciones/<uuid>`, sin título, cuerpo, contacto, foto, zona ni coordenadas.
Cancelar no muestra una confirmación de entrega. El rectángulo de origen permite usar iPad.

Configurar `--dart-define=PUBLIC_APP_URL=https://<dominio-real>` después de acordar y desplegar
la página pública y su autorización. Debe ser un origen HTTPS sin usuario, ruta, consulta ni
fragmento. El valor por defecto está vacío: se informa que compartir aún no está disponible.
La página de destino, asociación de enlaces de Android/iOS y dominio siguen pendientes del
despliegue y de la integración A/B/D. No se inventa un enlace funcional.

`ShareService` se inyecta para pruebas. Ver `test/features/compartir/` para validación y privacidad.
La selección/cancelación real en WhatsApp requiere un teléfono y comprobación manual.
