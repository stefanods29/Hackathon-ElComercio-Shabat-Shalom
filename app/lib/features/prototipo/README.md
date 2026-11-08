# Prototipo de interfaz Winki

La entrada del prototipo es `lib/prototype_main.dart`. Sus datos y acciones siguen
siendo simulados; estas correcciones se limitan a la interfaz y la navegación.

## Publicar en tres toques

El recorrido empieza en la pantalla principal, después del ingreso y la elección
de zona:

1. Tocar **Publicar** en la barra inferior.
2. Elegir cualquiera de los seis tipos de publicación.
3. Tocar **Publicar** en el botón fijo al pie del formulario.

Elegir un tipo completa un título válido utilizando las sugerencias del módulo
`publicar`. No se abre el teclado automáticamente. Escribir un título propio o
añadir una descripción es opcional. Cambiar de tipo conserva un título escrito
por la persona y actualiza un título que todavía sea la sugerencia anterior.

La pestaña y la ruta `/publicar` utilizan `ProtoPublishForm`; los enlaces
`/publicar/:tipo` también completan el tipo y su título. La confirmación conserva
el comportamiento simulado: muestra un mensaje y abre el muro, sin persistir ni
enviar publicaciones.

## Navegación y adaptación

- `ProtoHomeTab` identifica las cuatro pestañas. El parámetro `vista` permite
  abrir el muro explícitamente, por ejemplo `/mapa?vista=muro`.
- `ProtoNavigation.open` conserva la pantalla anterior. Las flechas de regreso
  vuelven a ella; los botones **Volver al muro** abren siempre esa pestaña.
- El formulario y la cuenta comparten componentes entre sus rutas y pestañas.
  `IndexedStack` conserva el borrador al cambiar de pestaña.
- El menú y las pantallas largas se pueden desplazar. Los marcadores simulados
  se distribuyen según el ancho disponible y el tamaño del texto.
- Las seis casillas del código comparten el ancho disponible y se actualizan al
  escribir. El campo real conserva su etiqueta para lectores de pantalla.
- Los estados comparten `ProtoStatusBadge`, con texto, icono y colores oscuros.
  Los textos incorporados están en `lib/l10n/app_es.arb`.

## Revisión pendiente en ejecución

Esta entrega no se compiló ni se probó en ejecución, por indicación del usuario.
En la revisión visual conviene recorrer los tres toques desde mapa y muro,
regresar desde los detalles y el tutorial, y revisar las pantallas con ancho
reducido y texto al 200 %. No se afirma una certificación de accesibilidad.
