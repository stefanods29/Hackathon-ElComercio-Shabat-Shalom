# app/inicio-de-sesion-y-cuenta Specification

## Purpose
Que cualquier vecino entre a la app con su teléfono, elija su zona y controle su cuenta (cerrar sesión o un teléfono perdido) sin ayuda.

## Requirements

### Requirement: Ingresar con el teléfono
La app SHALL permitir ingresar en dos pantallas, el número de teléfono y el código de 6 dígitos, con teclado numérico y autocompletado del código. Los errores MUST explicarse en lenguaje simple junto al campo.

#### Scenario: Código incorrecto
- **WHEN** el vecino escribe un código equivocado
- **THEN** ve "El código no es correcto o ya venció." junto al campo y puede intentarlo de nuevo

#### Scenario: Demasiados intentos
- **WHEN** la API responde 429 `demasiados_intentos`
- **THEN** la app dice cuántos minutos esperar y desactiva el botón hasta entonces

#### Scenario: Android confirma el número por su cuenta
- **WHEN** con el ingreso por Firebase, Android lee el SMS o confirma el número sin enviarlo
- **THEN** la app entra sin que el vecino escriba el código, y si también lo escribe no se abre una segunda sesión

### Requirement: Elegir la zona
Si el vecino no tiene zona, la app SHALL pedirle que la elija de una lista antes de mostrarle el muro.

#### Scenario: Primer ingreso
- **WHEN** un vecino recién registrado verifica su código
- **THEN** ve "Elige tu zona" y, al elegirla, llega al muro de esa zona

### Requirement: Controlar la cuenta
La pantalla "Mi cuenta" SHALL ofrecer cerrar sesión, avisando que se borran los datos del celular, y MUST ofrecer cerrar la sesión en todos los dispositivos si el teléfono se perdió.

#### Scenario: Teléfono perdido
- **WHEN** el vecino toca "Perdí mi teléfono" y confirma
- **THEN** todas sus sesiones quedan cerradas y el teléfono perdido ya no recibe datos nuevos
