## Why

En una emergencia el vecino necesita pedir ayuda en tres toques, saber en qué estado está su pedido
y qué hacer mientras tanto, aunque no tenga señal (secciones 7.1, 7.2 y 7.4). El Lote D de la
Fase 2 hace esas pantallas sobre los repositorios del Lote A y el contrato del Lote B, sin prometer
una atención que nadie garantiza.

## What Changes

- Inicio en modo emergencia con el tablero: Necesito ayuda · Puedo ayudar · Recursos · Directorio.
- "Necesito ayuda" en tres toques y el estado real del pedido, con las alternativas oficiales
  siempre visibles (116, 105 y 106) y el punto de encuentro más cercano en el mapa offline.
- "Puedo ayudar" y la lista de recursos con su antigüedad, su verificación y la fuente oficial.
- Contactos de emergencia cifrados por cuenta y un SMS preparado, nunca enviado por la app.
- Ahorro de datos: sin imágenes en modo emergencia.
- Puerto `EmergencyRepository`: práctica aislada en memoria; la cuenta real usa la cola y los
  streams de A y la API de B (integración de la Fase 2).

## Capabilities

### New Capabilities
- `emergencias/tablero-de-emergencia`: inicio, pedido propio, ofertas, recursos y contactos.

## Impact

App (`app/lib/features/emergencias/`, router, textos y política de imágenes). No incluye la
consola (Lote C), el quechua (Fase 3) ni la prueba con vecinos del simulacro.
