# Spec Delta

## ADDED Requirements

### Requirement: Buscar favores cercanos
`GET /v1/publicaciones?lat=&lng=&radio=` SHALL devolver las publicaciones abiertas dentro del radio (hasta 5 km), ordenadas por distancia, con paginación por cursor y sin exponer ubicaciones exactas.

#### Scenario: Favores a menos de 2 km
- **WHEN** un vecino busca favores a 2 km de su ubicación aproximada
- **THEN** recibe solo publicaciones abiertas dentro de ese radio, de la más cercana a la más lejana

### Requirement: Cancelar y resolver
El autor SHALL poder cancelar una publicación abierta, y el autor o quien tomó el favor MUST poder marcarla como resuelta, con concurrencia optimista e idempotencia.

#### Scenario: Favor cumplido
- **WHEN** el autor marca como resuelto un favor en curso con la versión vigente
- **THEN** el favor queda resuelto y sube su versión

### Requirement: Límites diarios
La API SHALL limitar la cantidad de publicaciones por vecino y por día y MUST responder 429 con un mensaje claro al superarlo.

#### Scenario: Spam en el muro
- **WHEN** un vecino supera el límite diario de publicaciones
- **THEN** la API responde 429 `limite_diario_alcanzado`
