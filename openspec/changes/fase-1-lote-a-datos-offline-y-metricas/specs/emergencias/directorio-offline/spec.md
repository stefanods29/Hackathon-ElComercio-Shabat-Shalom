# Spec Delta

## Purpose

Que los números oficiales, los puntos de encuentro, los centros de salud y los albergues estén
siempre en el celular, con su fuente y su fecha de verificación, aunque no haya señal (secciones
3.4 y 7.3 de la arquitectura).

## ADDED Requirements

### Requirement: Directorio publicado con contrato
El directorio de emergencia SHALL publicarse como un archivo JSON por distrito que cumple
`contracts/directorio-emergencia.schema.json`, junto con un índice que indica la versión, el hash
SHA-256 y las zonas de cada archivo. Cada entrada MUST tener tipo, nombre, fuente y fecha de
verificación.

#### Scenario: Entrada sin fuente
- **WHEN** un curador agrega una entrada sin `fuente` al archivo de un distrito
- **THEN** la verificación del repositorio falla y el archivo no se publica

#### Scenario: Índice desactualizado
- **WHEN** el hash de un archivo no coincide con el que declara el índice
- **THEN** la verificación del repositorio falla

### Requirement: Descarga verificada
La app SHALL descargar el archivo del distrito de su zona al iniciar sesión y luego como máximo una
vez al día. MUST descartar un archivo cuyo hash o cuyo contenido no sea válido y conservar la
última copia válida.

#### Scenario: Descarga corrupta
- **WHEN** el archivo descargado no coincide con el hash del índice
- **THEN** la app conserva la copia anterior y lo vuelve a intentar en la siguiente revisión

#### Scenario: Sin cambios
- **WHEN** la versión publicada es la misma que ya tiene el celular
- **THEN** la app no vuelve a descargar el archivo

### Requirement: Disponible sin señal
La última copia válida SHALL abrirse sin conexión. Si el celular nunca descargó el directorio, la
app MUST mostrar la copia de respaldo incluida en la app, con los números 116, 105 y 106, su fuente
y su fecha.

#### Scenario: Primer uso en modo avión
- **WHEN** el vecino abre el directorio de emergencia en modo avión sin haberlo descargado nunca
- **THEN** ve los números 116, 105 y 106 con su fuente y su fecha de verificación

### Requirement: Fuente y fecha visibles
Cada dato del directorio SHALL mostrar su fuente y su fecha de verificación, legibles con la letra
del sistema al 200 %.

#### Scenario: Punto de encuentro
- **WHEN** el vecino ve un punto de encuentro
- **THEN** ve quién lo informó y cuándo se verificó por última vez

### Requirement: Datos posiblemente desactualizados
Una entrada cuya fecha de verificación supera el umbral configurado para su tipo SHALL mostrarse
como "posiblemente desactualizada", sin ocultarla.

#### Scenario: Verificación antigua
- **WHEN** un punto de encuentro se verificó hace 45 días y el umbral de ese tipo es de 30 días
- **THEN** el punto sigue visible y se marca como posiblemente desactualizado

### Requirement: Descarga sin datos personales
La descarga del directorio MUST NOT enviar el token, el teléfono, la ubicación ni ningún
identificador del vecino; es información pública servida por la CDN.

#### Scenario: Solicitud a la CDN
- **WHEN** la app descarga el índice o el archivo de su distrito
- **THEN** la solicitud no lleva cabecera de autorización ni identificadores del vecino
