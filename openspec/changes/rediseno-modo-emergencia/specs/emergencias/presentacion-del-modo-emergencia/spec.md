# Spec Delta

## Purpose

Que el vecino entienda el modo emergencia de un vistazo: llamar primero, una sola acción principal
por pantalla y los avisos de honestidad como estados breves, sin perder ninguna precaución.

## ADDED Requirements

### Requirement: Llamadas primero
El tablero de emergencia SHALL mostrar arriba, antes de cualquier otra acción, un botón por cada
número oficial del directorio con el número grande y un nombre corto. El lector de pantalla MUST
leer el nombre completo y el número de cada botón. En práctica los botones MUST NOT abrir el
marcador.

#### Scenario: El vecino abre el tablero
- **WHEN** el vecino abre "Emergencia" en un teléfono de 414 × 896 con el texto al 100 %
- **THEN** ve los botones 116, 105 y 106 y "Necesito ayuda" sin deslizar

#### Scenario: Texto grande
- **WHEN** el texto del sistema está al 200 %
- **THEN** los botones de llamada y los accesos secundarios se apilan uno por fila sin cortes

#### Scenario: Teléfono angosto
- **WHEN** los tres botones no tienen espacio para su nombre al tamaño de letra del vecino
- **THEN** se apilan con el número y el nombre en una línea, y ninguna palabra se parte

### Requirement: Una acción principal por pantalla
El tablero SHALL tener una sola acción destacada, "Necesito ayuda", con las necesidades como
subtítulo. "Puedo ayudar", "Recursos cerca", "Números y lugares" y "Mis contactos" SHALL mostrarse
como accesos secundarios. Sin cobertura confirmada, pedir y ofrecer ayuda MUST quedar deshabilitados
y un aviso breve SHALL explicarlo.

#### Scenario: Zona sin coordinación
- **WHEN** el vecino abre el tablero en una zona sin coordinación confirmada
- **THEN** ve el aviso de cobertura en una línea, las llamadas arriba y los botones de pedir y ofrecer deshabilitados

### Requirement: Un nombre para cada cosa
"Estoy en emergencia" SHALL nombrar solo el botón del inicio que cambia la app al modo emergencia, y
al tocarlo la app SHALL decir que funciona sin internet y que no avisa a nadie. El directorio SHALL
llamarse "Números y lugares" y MUST NOT ofrecer otro botón para activar el modo.

#### Scenario: Activar desde el inicio
- **WHEN** el vecino toca "Estoy en emergencia" en el inicio
- **THEN** la app abre la pestaña Emergencia y un mensaje dice que el modo no avisa a nadie

### Requirement: Inicio y Emergencia separados
Con el modo emergencia encendido o un evento activo, la app SHALL abrir la pestaña Emergencia, e
Inicio SHALL seguir mostrando el muro con un aviso del modo y un botón para ir a Emergencia. Inicio
MUST NOT repetir el tablero de emergencia.

#### Scenario: Llega un evento de la zona
- **WHEN** se activa un evento mientras el vecino mira el muro
- **THEN** la app pasa a la pestaña Emergencia y, al volver a Inicio, ve el muro con el aviso

### Requirement: Estado del pedido como línea de tiempo
"Mi pedido" SHALL mostrar primero el estado real como una banda de color con ícono y una frase
corta, y después el historial como una línea de tiempo con la hora de cada paso, el paso actual y
los que faltan. Mientras el pedido solo está en el celular, la línea de tiempo MUST NOT mostrar
pasos siguientes como "Enviado". Las llamadas SHALL quedar al final de la pantalla.

#### Scenario: Pedido en camino
- **WHEN** la coordinación marca el pedido "En camino"
- **THEN** el vecino ve la banda "En camino", los pasos cumplidos con su hora, "Atendido" como pendiente y el botón para confirmar que recibió ayuda

#### Scenario: Pedido sin señal
- **WHEN** el pedido sigue guardado en el celular
- **THEN** la banda dice que nadie lo ha visto y ningún texto de la pantalla dice "Enviado"

### Requirement: Recursos cerca
La lista de recursos SHALL mostrar cada recurso con un ícono por tipo, su lugar y etiquetas de
antigüedad y verificación, del más reciente al más antiguo, con filtros por tipo. Un recurso
antiguo SHALL pasar a una etiqueta ámbar que pide confirmar antes de ir. La misma pantalla SHALL
ofrecer los pedidos agrupados por sector, sin datos de quién los hizo, y el reporte de un recurso en
una pantalla propia.

#### Scenario: Recurso que pudo cambiar
- **WHEN** un recurso supera el plazo de su tipo
- **THEN** su etiqueta dice "Hace 3 horas · confirma antes de ir" y el lector de pantalla lee que está posiblemente desactualizado

### Requirement: Reportar un recurso
El reporte de un recurso SHALL elegir el tipo entre opciones con ícono, sin menú desplegable. Con la
cuenta real MUST NOT llevar texto libre: lleva tipo, cantidad y punto aproximado. En práctica el
detalle SHALL poder dictarse por voz.

#### Scenario: Reportar agua
- **WHEN** el vecino toca "Agua", sube la cantidad con el botón "Más" y reporta
- **THEN** la app guarda el reporte con el tipo agua y esa cantidad, sin texto libre

### Requirement: Práctica sin párrafos
En práctica, cada pantalla de emergencia SHALL mostrar un chip "Práctica" en la barra superior en
lugar de un párrafo. Al tocarlo SHALL explicar que nada se envía a nadie y ofrecer las simulaciones
disponibles en esa pantalla. Las simulaciones MUST NOT aparecer fuera de práctica. En práctica,
llamar y preparar un SMS MUST NOT abrir otras aplicaciones; el dictado SHALL funcionar, porque solo
llena un campo en el celular.

#### Scenario: Demostración del flujo
- **WHEN** quien presenta toca "Práctica" en "Mi pedido" y elige el siguiente paso
- **THEN** la línea de tiempo avanza un paso y la pantalla sigue marcada como práctica
