# Spec Delta

## MODIFIED Requirements

### Requirement: Elegir la zona
`GET /v1/zonas` SHALL listar las zonas disponibles sin su polígono, y `PUT /v1/yo/zona` MUST asignar la zona a un vecino que todavía no la tiene, o cambiarla como máximo una vez cada 30 días, y devolver un token de acceso que ya la incluye. Al cambiar de zona, el nivel de confianza vuelve a 0.

#### Scenario: Vecino nuevo elige su zona
- **WHEN** un vecino sin zona elige la zona piloto
- **THEN** recibe un token con esa zona y su siguiente sincronización trae el muro de la zona

#### Scenario: Vecino que se muda
- **WHEN** un vecino que eligió su zona hace más de 30 días elige otra
- **THEN** recibe un token con la zona nueva y nivel 0, y se registra `identidad.zona_cambiada`

#### Scenario: Zona ya elegida
- **WHEN** un vecino que eligió o cambió su zona hace menos de 30 días intenta cambiarla
- **THEN** la API responde 409 `cambio_de_zona_muy_pronto` con la fecha desde la que podrá hacerlo

#### Scenario: Misma zona
- **WHEN** un vecino elige la zona que ya tiene
- **THEN** la API responde 200 con su sesión y no cambia su nivel
