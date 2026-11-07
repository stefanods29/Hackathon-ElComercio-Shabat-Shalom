# app/almacenamiento-local-cifrado Specification

## Purpose
Proteger los datos que viven en el celular si se pierde el teléfono o lo usa otra persona (secciones 8.3 y 8.4).

## Requirements

### Requirement: Base local cifrada
La base local SHALL estar cifrada con una clave aleatoria generada en el dispositivo y guardada en Keychain o Keystore; sin esa clave la base MUST NOT poder abrirse.

#### Scenario: Copia del archivo de la base
- **WHEN** alguien copia el archivo de la base local fuera de la app
- **THEN** no puede leer su contenido sin la clave

### Requirement: Cerrar sesión borra todo
Cerrar sesión SHALL desconectar la sincronización y borrar por completo la base local y su clave.

#### Scenario: Otra persona va a usar el teléfono
- **WHEN** el vecino cierra sesión
- **THEN** al volver a abrir la app no queda ningún dato suyo en el celular

### Requirement: Caducidad local de datos sensibles
Los datos sensibles SHALL borrarse del celular al cerrarse el caso o al vencer su plazo de caducidad, aunque el teléfono siga sin conexión.

#### Scenario: Plazo vencido sin señal
- **WHEN** vence la caducidad de un caso y el celular no tiene conexión
- **THEN** la app borra el detalle sensible al abrirse o en su siguiente revisión periódica

### Requirement: Sesión revocada desde otro dispositivo
Si al reconectar la API informa que la sesión fue revocada, la app SHALL borrar la base local y volver al inicio de sesión.

#### Scenario: Teléfono reportado como perdido
- **WHEN** el vecino revoca sus sesiones desde otro dispositivo y el teléfono perdido se reconecta
- **THEN** el teléfono perdido borra su base local
