# Spec Delta

## Purpose

Guardar las fotos de reseñas y servicios en el almacenamiento de objetos, nunca en la base de datos,
sin metadatos de ubicación y sin publicarlas antes que su contenido (secciones 3.4, 5.1 y 10 de la
arquitectura).

## ADDED Requirements

### Requirement: Registrar un archivo
`POST /v1/archivos` SHALL registrar un archivo con un id UUIDv7 del celular, su tipo y su tamaño, y
devolver una URL firmada de subida que vence en minutos. MUST rechazar tipos que no sean JPEG o WebP
y archivos de más de 2 MB.

#### Scenario: Foto válida
- **WHEN** un vecino registra una foto JPEG de 240 KB
- **THEN** recibe una URL de subida que vence en 10 minutos y el archivo queda `pendiente`

#### Scenario: Tipo no permitido
- **WHEN** el celular registra un archivo `image/gif`
- **THEN** la API responde 422 `tipo_de_archivo_no_permitido`

### Requirement: Confirmar y procesar
`POST /v1/archivos/{id}/confirmar` SHALL encolar el procesamiento solo para el dueño del archivo. El
trabajo MUST comprobar el tipo real por su firma de bytes y rechazar el archivo si no coincide.

#### Scenario: Archivo disfrazado
- **WHEN** se sube un ejecutable con extensión .jpg y se confirma
- **THEN** el archivo queda `rechazado` y no se genera ninguna variante

### Requirement: Segunda barrera de privacidad
El procesamiento SHALL volver a borrar EXIF, GPS y todo metadato de la imagen, y generar las
variantes `miniatura` y `grande` en WebP con su ancho, alto y `blurhash`.

#### Scenario: Foto con GPS
- **WHEN** se procesa una foto que todavía trae coordenadas GPS en su EXIF
- **THEN** ninguna variante guardada contiene metadatos de ubicación

### Requirement: Publicación con su contenido
Las variantes de un archivo SHALL publicarse en la CDN, en `media/<archivoId>/<variante>.webp`, solo
cuando su reseña o su servicio se publica, y MUST retirarse de la CDN si el contenido se oculta.

#### Scenario: Reseña todavía en revisión
- **WHEN** alguien pide la variante de una foto cuya reseña está en revisión
- **THEN** la CDN responde 404

#### Scenario: Reseña ocultada
- **WHEN** la moderación oculta una reseña publicada con fotos
- **THEN** sus variantes dejan de servirse desde la CDN

### Requirement: Solo identificadores en los eventos
El evento `media.archivo_listo` SHALL llevar solo el id, el dueño, el propósito, las dimensiones y el
`blurhash`, nunca rutas privadas ni URLs firmadas.

#### Scenario: Archivo procesado
- **WHEN** termina el procesamiento de una foto
- **THEN** el evento no incluye la clave del almacenamiento ni una URL firmada
