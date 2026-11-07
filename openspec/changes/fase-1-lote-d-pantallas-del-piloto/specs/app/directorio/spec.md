# Spec Delta

## Purpose

Que cualquier vecino encuentre en su celular un servicio cercano de confianza y ofrezca el suyo en 3
toques, aunque no tenga señal (secciones 6 y 7.3 de la arquitectura).

## ADDED Requirements

### Requirement: Servicios cerca
La pantalla "Servicios cerca" SHALL mostrar las categorías con ícono y texto, una búsqueda que
tolera tildes y errores, y una lista con distancia aproximada, estrellas y "Visto Bueno de tu zona".

#### Scenario: Buscar un gasfitero
- **WHEN** el vecino escribe "gasfiter" en la búsqueda
- **THEN** ve los servicios de gasfitería con su distancia, sus estrellas y sus Visto Bueno de la zona

### Requirement: Filtro de emergencia y mapa
La pantalla SHALL ofrecer el filtro "Útil en emergencia" y un acceso al mapa sin conexión con las
ubicaciones aproximadas de los servicios.

#### Scenario: Solo útiles en emergencia
- **WHEN** el vecino activa "Útil en emergencia"
- **THEN** la lista muestra solo los servicios marcados como disponibles en emergencia

### Requirement: Directorio sin señal
Sin conexión, la pantalla SHALL mostrar lo descargado con "Actualizado hace X" y, si no hay datos,
un estado vacío que explica qué hacer.

#### Scenario: Modo avión sin datos descargados
- **WHEN** el vecino abre el directorio en modo avión sin haber sincronizado nunca
- **THEN** ve un mensaje que explica que necesita conexión una vez para descargar los servicios

### Requirement: Perfil del proveedor
El perfil SHALL mostrar los servicios del proveedor, el resumen de sus reseñas, su Visto Bueno y el
botón compartir, sin teléfono ni ubicación exacta.

#### Scenario: Ver un proveedor
- **WHEN** el vecino abre el perfil de un proveedor
- **THEN** ve sus servicios, sus estrellas y el botón compartir, y ningún dato de contacto

### Requirement: Ofrecer un servicio en 3 toques
"Ofrezco un servicio" SHALL requerir como máximo 3 toques desde el inicio: el botón "+", "Ofrezco un
servicio" y "Publicar" en un formulario mínimo con categoría y ubicación sugeridas.

#### Scenario: Publicación rápida
- **WHEN** un proveedor toca "+", "Ofrezco un servicio" y "Publicar" con los datos sugeridos
- **THEN** el servicio queda "Guardado en tu celular" con exactamente tres toques

### Requirement: Editar y retirar con el motivo
El proveedor SHALL poder editar y retirar su servicio, y si el servidor rechaza el cambio, MUST ver
el motivo en lenguaje simple y una alternativa.

#### Scenario: Servicio cambiado en otro celular
- **WHEN** el servidor responde 409 `conflicto_de_version` a una edición
- **THEN** el proveedor ve "El servicio cambió. Revísalo y vuelve a intentarlo." en "Acciones por revisar"
