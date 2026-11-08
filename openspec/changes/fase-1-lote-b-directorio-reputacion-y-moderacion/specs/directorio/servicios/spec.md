# Spec Delta

## Purpose

Que un vecino pueda ofrecer sus oficios y servicios a su zona, con un perfil de proveedor, sin
exponer su vivienda ni sus datos de contacto (secciones 4.2 y 5.3 de la arquitectura y ADR 0010).

## ADDED Requirements

### Requirement: Categorías del directorio
`GET /v1/categorias` SHALL listar las categorías con su id estable, nombre, ícono, orden y si es útil
en una emergencia, para cualquier vecino con sesión.

#### Scenario: Lista de categorías
- **WHEN** un vecino con sesión pide las categorías
- **THEN** recibe, entre otras, "Gasfitería" con su ícono y la marca de si es útil en emergencia

### Requirement: Perfil de proveedor
`PUT /v1/yo/proveedor` SHALL crear o actualizar el perfil de proveedor del vecino (nombre público y
descripción) de forma idempotente. MUST exigir nivel de confianza 1 o más y una zona.

#### Scenario: Primer perfil
- **WHEN** un vecino de nivel 1 guarda su nombre público "Gasfitería Don Luis"
- **THEN** queda registrado como proveedor de su zona

#### Scenario: Vecino recién registrado
- **WHEN** un vecino de nivel 0 intenta crear su perfil
- **THEN** la API responde 403 `nivel_de_confianza_insuficiente`

### Requirement: Publicar un servicio
`POST /v1/servicios` SHALL publicar un servicio con un id UUIDv7 generado en el celular, categoría,
título de 3 a 120 caracteres y ubicación, en la zona del proveedor. Repetir el mismo id del mismo
proveedor MUST devolver el servicio existente sin duplicarlo.

#### Scenario: Servicio válido
- **WHEN** un proveedor publica "Arreglo fugas y cambio caños" en Gasfitería
- **THEN** la API responde 201 con el servicio en versión 1 y registra el evento `directorio.servicio_publicado`

#### Scenario: Reintento del celular
- **WHEN** el celular reenvía el mismo servicio con otra `Idempotency-Key`
- **THEN** la API responde 200 y sigue existiendo un solo servicio

### Requirement: Ubicación privada y copia pública
El servicio SHALL guardar su ubicación exacta solo para las búsquedas y una copia pública redondeada
a 3 decimales. Solo si el proveedor acepta mostrar su local, la copia pública MUST ser la exacta.
Ninguna respuesta pública incluye la ubicación privada ni el teléfono.

#### Scenario: Servicio desde la casa del proveedor
- **WHEN** un proveedor publica un servicio en lat -12.085678 y lng -77.034567 sin aceptar mostrar su local
- **THEN** las respuestas y los Sync Streams muestran -12.086 y -77.035

### Requirement: Editar con concurrencia optimista
`PUT /v1/servicios/{id}` SHALL aceptar cambios solo del dueño y solo con la versión vigente. Con una
versión vieja MUST responder 409 `conflicto_de_version` con la versión esperada y la actual.

#### Scenario: Edición desde dos celulares
- **WHEN** el proveedor edita su servicio con la versión 1 cuando ya está en la versión 2
- **THEN** la API responde 409 `conflicto_de_version` y no cambia nada

#### Scenario: Otro vecino intenta editar
- **WHEN** un vecino que no es el dueño intenta editar el servicio
- **THEN** la API responde 403 `no_eres_el_dueno`

### Requirement: Retirar un servicio
`DELETE /v1/servicios/{id}` SHALL marcar el servicio con borrado lógico, solo por su dueño, de forma
idempotente, para que salga de las búsquedas y de los Sync Streams.

#### Scenario: Retiro repetido
- **WHEN** el celular repite el retiro de un servicio ya retirado
- **THEN** la API responde 204 sin error y el servicio sigue fuera del directorio

### Requirement: Perfil público
`GET /v1/proveedores/{id}` SHALL devolver el nombre público, la descripción y los servicios vigentes
del proveedor, sin teléfono ni ubicación exacta.

#### Scenario: Ver un proveedor
- **WHEN** un vecino abre el perfil de un proveedor de su zona
- **THEN** ve su nombre público, sus servicios y sus calificaciones, y ningún dato de contacto

### Requirement: Cambio de zona del proveedor
Cuando un proveedor cambia de zona, sus servicios de la zona anterior SHALL retirarse, para que no
queden servicios de alguien que ya no vive allí.

#### Scenario: Proveedor que se muda
- **WHEN** un proveedor con dos servicios cambia de zona
- **THEN** ambos servicios dejan de aparecer en la zona anterior y el proveedor puede publicarlos de nuevo en la nueva
