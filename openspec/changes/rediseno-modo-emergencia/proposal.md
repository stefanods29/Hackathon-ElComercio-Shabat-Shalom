## Why

El modo emergencia cumple las reglas de seguridad, pero cada precaución terminó escrita como un
párrafo: el tablero ocupaba 2,2 pantallas, tenía 152 palabras de texto corrido y 14 botones casi
iguales, y los números 116, 105 y 106 quedaban al final. "Estoy en emergencia" nombraba tres cosas
distintas. La revisión del 9 de noviembre de 2026 propuso pasar esa honestidad de párrafos a diseño
antes de la presentación de finalistas.

Lote dueño: D de la Fase 2 (tablero de emergencia). Implementa la experiencia de las secciones 7.1,
7.2 y 7.4 de la arquitectura con la meta de accesibilidad de la sección 6.

## What Changes

- Tablero de emergencia en una pantalla: franja roja arriba con un botón por número oficial, una
  línea de estado de conexión, la tarjeta del pedido propio, "Necesito ayuda" como única acción
  principal y una cuadrícula con "Puedo ayudar", "Recursos cerca", "Números y lugares" y
  "Mis contactos". El ahorro de datos queda en una fila.
- "Necesito ayuda" muestra las seis necesidades como una cuadrícula con ícono grande; el
  formulario hace dos preguntas ("¿Qué necesitas?" y "¿Dónde estás?"), con el dictado como ícono y
  la referencia de lugar opcional.
- "Mi pedido" muestra el estado como una banda de color y el historial como una línea de tiempo con
  la hora de cada paso. Las llamadas van al final.
- "Recursos" y "Recursos y pedidos de mi zona" se unen en "Recursos cerca", con filtros por tipo,
  antigüedad y verificación como etiquetas, una pestaña de pedidos por sector y un botón flotante
  para reportar en una pantalla propia. Así la vista de pedidos por zona también funciona en
  práctica.
- "Números y lugares de emergencia" abre con los tres números, uno por fila con su botón "Llamar";
  la fuente es una línea corta que abre la dirección web. Se quitan de esa pantalla los botones que
  activaban el modo.
- Un nombre por cosa: "Estoy en emergencia" solo en el botón rojo del inicio, que ahora avisa que no
  notifica a nadie y abre la pestaña Emergencia; el directorio se llama "Números y lugares"; el
  tablero, "Emergencia". Inicio deja de duplicar el tablero: en modo emergencia sigue mostrando el
  muro con un aviso que lleva a la pestaña Emergencia, y la app cambia sola a esa pestaña cuando se
  activa el modo o llega un evento.
- Los botones de llamada nunca cortan el número ni el nombre: si no caben tres al lado con el tamaño
  de letra del vecino, se apilan con el número y el nombre en la misma línea.
- "Reportar un recurso" elige el tipo en una cuadrícula con íconos (sin menú desplegable), con un
  contador de cantidad en la cuenta real y dictado por voz para el detalle en práctica. El dictado
  también funciona en práctica, porque solo llena el campo en el celular; llamar y preparar SMS
  siguen sin abrirse. Los textos del permiso de micrófono de iOS ya no hablan solo de reseñas.
- Práctica como un chip en la barra superior: al tocarlo explica que nada se envía y ofrece las
  simulaciones de la pantalla (emergencia en la zona, recurso, siguiente paso del pedido).
- Textos más cortos para los avisos de cobertura, conexión, ubicación y estados del pedido; los
  errores técnicos del muro y de publicar se reemplazan por mensajes del archivo de textos.
- Los datos de práctica de recursos usan lugares de barrio ("Local comunal", "Parroquia del
  barrio") en lugar de "Ejemplo ficticio".

Fuera de alcance (siguiente lote de mejoras, Fase 2 o 3 según decida el equipo): ubicación del
vecino con permiso, tutorial en el primer arranque, lugares y grupos de apoyo en el directorio,
ruta del servidor para "Puedo ayudar", datos de demostración con historia completa y los cambios
del muro (chip "Enviado" en publicaciones ajenas y tipos en mayúsculas).

## Capabilities

### New Capabilities
- `emergencias/presentacion-del-modo-emergencia`: cómo se presentan las pantallas del modo
  emergencia al vecino: jerarquía de acciones, llamadas siempre visibles, avisos breves, estado del
  pedido como línea de tiempo y práctica señalada sin párrafos.

### Modified Capabilities

## Impact

Solo la app: `app/lib/features/emergencias/` (pantallas y componentes visuales), el router (ruta
nueva `/emergencia/recursos/reportar`), `wrapping_app_bar.dart`, textos en `app_es.arb`, el muro y el
formulario de publicar (mensajes de error) y el tutorial (nombre del paso de emergencia). No cambia
el contrato de la API, los repositorios, la cola de envíos ni las reglas de cobertura y privacidad.
Las pruebas de widgets de emergencia y las referencias visuales de macOS se actualizan junto con el
cambio.
