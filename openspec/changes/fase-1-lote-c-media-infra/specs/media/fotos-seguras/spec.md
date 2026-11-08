## ADDED Requirements
### Requirement: Fotos privadas y sin metadatos personales
El sistema SHALL conservar las fotos privadas y eliminar EXIF/GPS antes de habilitar su vista procesada.
#### Scenario: Procesamiento válido
- **WHEN** un vecino confirma una imagen cuyo tamaño y huella coinciden con el registro
- **THEN** el worker produce una imagen limitada a 1280 píxeles, miniatura y blurhash sin metadatos
- **AND** otro vecino no puede consultar el archivo privado
#### Scenario: Recuperación
- **WHEN** el proceso se interrumpe antes de terminar una imagen
- **THEN** el siguiente worker recupera el trabajo mediante un arrendamiento acotado
### Requirement: Borradores recuperables
La app SHALL conservar borradores cifrados y mostrar que todavía no se enviaron cuando no hay red.
#### Scenario: Sin conexión
- **WHEN** el vecino selecciona una foto sin red
- **THEN** permanece guardada en su celular sin declararse publicada ni enviada
