# app/accesibilidad Specification

## Purpose
Que cualquier vecino, incluidas personas mayores o con baja visión, pueda usar la app con su teléfono tal como lo tiene configurado (meta WCAG 2.2 AA).

## Requirements

### Requirement: Contraste suficiente
Todo texto y todo ícono que transmite información SHALL tener un contraste de al menos 4,5:1 (texto normal) o 3:1 (texto grande e íconos) en los temas claro y oscuro.

#### Scenario: Revisión automática del tema
- **WHEN** corren las pruebas del tema
- **THEN** fallan si algún par de colores de texto y fondo no alcanza el contraste mínimo

### Requirement: Objetivos táctiles grandes
Todo control tocable SHALL medir al menos 48 × 48 dp.

#### Scenario: Botón de tomar favor
- **WHEN** se mide el botón "Tomar favor" en una prueba de widgets
- **THEN** su área tocable es de 48 dp o más en cada lado

### Requirement: Texto escalable sin cortes
Con el tamaño de letra del sistema al 200 %, las pantallas principales SHALL mostrar todo su texto sin cortes ni desbordes.

#### Scenario: Golden test con letra grande
- **WHEN** se renderiza el muro con escala de texto 2,0
- **THEN** no hay desbordes y el golden coincide con la referencia aprobada

### Requirement: Lector de pantalla
Cada control y cada estado SHALL tener una etiqueta semántica en español que TalkBack y VoiceOver lean de forma comprensible, y el color MUST NOT ser la única señal de un estado.

#### Scenario: TalkBack en el muro
- **WHEN** el lector de pantalla recorre una publicación pendiente de envío
- **THEN** anuncia el título, el tipo y "Guardado en tu celular"

### Requirement: Modo sencillo
La app SHALL ofrecer un "modo sencillo" con menos opciones visibles, textos más grandes y acciones principales destacadas, activable desde el menú y el tutorial.

#### Scenario: Persona mayor activa el modo sencillo
- **WHEN** activa el modo sencillo
- **THEN** el inicio muestra solo el muro y el botón de publicar, con letra más grande
