# Spec Delta

## Purpose

Que un vecino encuentre en línea los servicios cercanos que necesita, por categoría o por texto,
priorizando los que tienen el Visto Bueno de vecinos verificados, sin exponer ubicaciones exactas
(secciones 5.4 y 5.5 de la arquitectura).

## ADDED Requirements

### Requirement: Búsqueda por cercanía
`GET /v1/servicios` SHALL devolver los servicios vigentes dentro de un radio de 100 a 20 000 metros
alrededor de un punto, con paginación por cursor estable y un límite de 1 a 50 resultados por página.

#### Scenario: Servicios a menos de 2 km
- **WHEN** un vecino busca a 2 km de un punto de su zona
- **THEN** recibe solo servicios vigentes dentro de ese radio

#### Scenario: Recorrer las páginas
- **WHEN** el vecino pide la página siguiente con el cursor recibido
- **THEN** recibe los resultados siguientes sin repetidos ni saltos

### Requirement: Orden por confianza de la zona
Los resultados SHALL ordenarse primero por el número de Visto Bueno de vecinos verificados de la zona
del servicio y luego por el puntaje del ranking.

#### Scenario: Dos gasfiteros
- **WHEN** dos gasfiteros tienen el mismo puntaje y uno tiene más Visto Bueno de vecinos verificados
- **THEN** aparece primero el que tiene más Visto Bueno

### Requirement: Filtros de categoría y emergencia
La búsqueda SHALL poder filtrarse por una categoría y por servicios disponibles en una emergencia.

#### Scenario: Solo útiles en emergencia
- **WHEN** el vecino activa "Útil en emergencia"
- **THEN** solo recibe servicios marcados como disponibles en emergencia

### Requirement: Texto tolerante a tildes y errores
La búsqueda por texto SHALL encontrar servicios aunque la consulta no lleve tildes o tenga errores
leves de tipeo.

#### Scenario: Gásfiter
- **WHEN** el vecino busca "gásfiter"
- **THEN** encuentra el servicio "Gasfitero a domicilio"

### Requirement: Distancia sin ubicación exacta
Cada resultado SHALL indicar `distanciaMetros` redondeada a múltiplos de 50 y la ubicación pública.
La respuesta MUST NOT incluir la ubicación privada, y la API MUST NOT guardar el punto de búsqueda.

#### Scenario: Resultado cercano
- **WHEN** un servicio está a 437 metros del punto de búsqueda
- **THEN** la respuesta indica 450 metros y la ubicación pública del servicio
