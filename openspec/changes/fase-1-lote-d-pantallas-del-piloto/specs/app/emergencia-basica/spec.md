# Spec Delta

## Purpose

Que en una emergencia cualquier vecino llegue en un toque a los números oficiales, los puntos de
encuentro, los centros de salud y los albergues, aunque no tenga señal, sin que la app prometa lo que
nadie garantiza (secciones 7.4 y 9.4 de la arquitectura).

## ADDED Requirements

### Requirement: Botón siempre visible
El inicio SHALL mostrar siempre el botón "Estoy en emergencia", que abre el directorio de emergencia
en un toque y funciona sin señal, también en el modo sencillo.

#### Scenario: Modo avión
- **WHEN** el vecino toca "Estoy en emergencia" en modo avión
- **THEN** ve el directorio de emergencia descargado o, si no hay, la copia de respaldo con 116, 105 y 106

### Requirement: Llamar en un toque
Cada número SHALL tener un botón para llamar que abre el marcador del teléfono con el número ya
escrito.

#### Scenario: Llamar a los bomberos
- **WHEN** el vecino toca "Llamar" junto al 116
- **THEN** se abre el marcador del teléfono con el 116

### Requirement: Datos con fuente, fecha y mapa
Cada entrada SHALL mostrar su fuente, su fecha de verificación y, si corresponde, la marca
"posiblemente desactualizado"; los puntos de encuentro MUST poder abrirse en el mapa sin conexión.

#### Scenario: Punto de encuentro
- **WHEN** el vecino toca un punto de encuentro
- **THEN** lo ve en el mapa sin conexión junto con su fuente y su fecha

### Requirement: Mensajes que gestionan expectativas
La pantalla SHALL mostrar "Esta app conecta vecinos; no reemplaza a los servicios de emergencia" y
"Si hay riesgo para la vida, llama al 116, 105 o 106".

#### Scenario: Abrir la emergencia
- **WHEN** el vecino abre la pantalla de emergencia
- **THEN** ve ambos mensajes antes de la lista

### Requirement: Tutorial actualizado
El tutorial y el modo práctica SHALL incluir las pantallas nuevas del piloto, con su contenido desde
un JSON de la CDN y una copia incluida en la app.

#### Scenario: Tutorial sin conexión
- **WHEN** el vecino repite el tutorial en modo avión
- **THEN** ve los pasos de la copia incluida en la app, incluido el botón "Estoy en emergencia"
