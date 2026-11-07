# Spec Delta

## Purpose

Que un vecino agregue fotos livianas y sin ubicación a una reseña o un servicio, aunque no tenga
señal, y vea siempre si ya se subieron (secciones 3.4 y 10 de la arquitectura).

## ADDED Requirements

### Requirement: Foto liviana y limpia en el celular
La app SHALL permitir tomar o elegir una foto, comprimirla a unos 250 KB con el lado mayor de 1 280
px como máximo y borrar sus metadatos EXIF y GPS antes de guardarla en la cola.

#### Scenario: Foto de la cámara con GPS
- **WHEN** el vecino toma una foto con la ubicación activada en la cámara
- **THEN** el archivo que queda en la cola no tiene metadatos de ubicación y pesa unos 250 KB o menos

### Requirement: Cola persistente de subida
Cada foto SHALL quedar en una cola persistente que sobrevive al cierre de la app y muestra
"Guardado en tu celular", "Enviando…", "Enviado" o "No se pudo completar". MUST reintentar con la
misma política de espera que la cola de datos.

#### Scenario: Sin señal
- **WHEN** el vecino agrega una foto en modo avión
- **THEN** la ve "Guardado en tu celular" y se sube sola al volver la conexión

#### Scenario: Rechazo definitivo
- **WHEN** el servidor rechaza el archivo por su tipo
- **THEN** la foto queda "No se pudo completar" con el motivo y no se reintenta

### Requirement: Solo con Wi-Fi si se elige
La app SHALL ofrecer la opción "Subir fotos solo con Wi-Fi" y, con ella activada, MUST NOT subir
fotos por datos móviles.

#### Scenario: Datos móviles
- **WHEN** la opción está activada y el celular solo tiene datos móviles
- **THEN** las fotos esperan en la cola hasta que haya Wi-Fi

### Requirement: Registro y foto por separado
El registro (reseña o servicio) SHALL viajar por la cola de datos con su `archivoId`, y la foto por su
propia cola, de modo que una foto lenta no bloquee el resto de acciones.

#### Scenario: Reseña con foto pendiente
- **WHEN** la reseña ya se envió y su foto sigue subiendo
- **THEN** la reseña figura "Enviado" y la foto muestra su propio estado

### Requirement: Fotos pendientes al salir
Las fotos pendientes SHALL poder descartarse sin subirse cuando el vecino cierra sesión o borra su
cuenta.

#### Scenario: Cerrar sesión
- **WHEN** el vecino cierra sesión con dos fotos en cola
- **THEN** ambas se borran del celular y ninguna se sube
