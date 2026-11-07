# Spec Delta

## Purpose

Que el vecino nunca crea que algo se envió cuando no fue así, y que sepa qué tan actual es lo que está viendo (secciones 3.4 y 7.3).

## ADDED Requirements

### Requirement: Aviso destacado de lo no enviado
Toda acción en estado "Guardado en tu celular" SHALL mostrarse con un aviso destacado que diga que nadie más la ha recibido todavía.

#### Scenario: Favor tomado sin señal
- **WHEN** el vecino toma un favor sin conexión
- **THEN** la tarjeta muestra "Guardado en tu celular · Todavía no se envió. Nadie más lo ha recibido."

### Requirement: Frescura de los datos
Cada pantalla de datos SHALL mostrar "Actualizado hace X" y, sin conexión, un aviso de que algunos datos pueden haber cambiado, con textos en archivos de idioma y plurales correctos.

#### Scenario: Sin conexión hace 5 minutos
- **WHEN** el celular perdió la conexión hace 5 minutos
- **THEN** el aviso dice "Estás viendo datos de hace 5 minutos; algunos pueden haber cambiado."

### Requirement: Acciones por revisar
Las acciones rechazadas de forma definitiva SHALL aparecer en una bandeja "Acciones por revisar" con el motivo del servidor en lenguaje simple y al menos una alternativa (por ejemplo, ver favores parecidos o volver a publicar).

#### Scenario: El favor ya lo tomó otro vecino
- **WHEN** una acción recibe el motivo `favor_no_disponible`
- **THEN** la bandeja muestra "Otro vecino ya tomó este favor" y el botón "Ver favores parecidos"

### Requirement: Indicador de pendientes
La pantalla principal SHALL indicar cuántas acciones siguen pendientes de envío.

#### Scenario: Tres acciones en cola
- **WHEN** hay tres acciones "Guardado en tu celular"
- **THEN** el inicio muestra "3 pendientes de envío"
