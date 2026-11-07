# Spec Delta

## Purpose

Que cada celular tenga el directorio de servicios y la reputación de su zona para consultarlos sin
señal, sin exponer la ubicación exacta ni los datos de contacto de nadie (secciones 3.4 y 8.1 de la
arquitectura y ADR 0010).

## ADDED Requirements

### Requirement: Categorías para todos los vecinos
Al conectarse, todo celular con sesión SHALL recibir automáticamente la lista completa de
categorías del directorio, con su nombre, su ícono, su orden y si es útil en una emergencia.

#### Scenario: Vecino recién registrado
- **WHEN** un vecino de cualquier zona conecta su celular por primera vez
- **THEN** recibe todas las categorías, incluida la marca "útil en emergencia" de cada una

### Requirement: Servicios y proveedores de la zona
El celular SHALL recibir los servicios y los perfiles de proveedor de la zona del vecino que no
estén borrados ni ocultos, y MUST NOT recibir los de otras zonas.

#### Scenario: Vecino de la zona piloto
- **WHEN** un vecino de la zona piloto sincroniza
- **THEN** recibe los servicios vigentes de su zona y ninguno de la zona vecina

#### Scenario: El dueño retira su servicio
- **WHEN** un proveedor borra su servicio y los celulares de la zona sincronizan
- **THEN** el servicio desaparece de su base local

### Requirement: Ubicación pública aproximada
La ubicación de un servicio que llega a los celulares SHALL ser la copia pública redondeada a 3
decimales (unos 110 m), salvo que el proveedor haya aceptado mostrar la ubicación exacta de su
local. Ningún stream automático MUST incluir la ubicación exacta de una vivienda, teléfonos ni
datos de contacto.

#### Scenario: Servicio sin consentimiento de ubicación exacta
- **WHEN** un proveedor registra su servicio en lat -12.085678 y lng -77.034567 sin aceptar mostrar su local
- **THEN** los celulares de la zona reciben lat -12.086 y lng -77.035

#### Scenario: Local a la calle con consentimiento
- **WHEN** el proveedor acepta mostrar la ubicación exacta de su local
- **THEN** los celulares reciben esa ubicación y ningún otro dato de contacto

#### Scenario: Revisión de la configuración
- **WHEN** corren las pruebas de los Sync Streams
- **THEN** fallan si un stream automático selecciona la ubicación privada, un teléfono o el autor de una reseña pública

### Requirement: Solo reseñas publicadas para la zona
El celular SHALL recibir solo las reseñas publicadas de los servicios de su zona, con sus fotos, y
sin identificar a su autor. Una reseña en revisión u oculta MUST NOT llegar a otros vecinos.

#### Scenario: Reseña en revisión
- **WHEN** un vecino escribe una reseña que todavía está en revisión
- **THEN** los demás vecinos de la zona no la reciben, ni tampoco sus fotos

#### Scenario: Reseña publicada
- **WHEN** la moderación publica la reseña
- **THEN** los vecinos de la zona reciben su calificación, su comentario y sus fotos, sin el autor

### Requirement: Lo propio del vecino
El celular SHALL recibir todas las reseñas del propio vecino en cualquier estado y sus Visto Bueno,
para que siempre vea lo que hizo y en qué estado está.

#### Scenario: Autor de una reseña en revisión
- **WHEN** el autor de una reseña en revisión sincroniza
- **THEN** ve su reseña marcada "En revisión" aunque los demás todavía no la reciban

### Requirement: Lo oculto sale del celular
Un servicio, un perfil, una reseña o una foto ocultados por moderación SHALL dejar de pertenecer a
los streams y MUST borrarse de los celulares en la siguiente sincronización.

#### Scenario: El moderador oculta una reseña
- **WHEN** un moderador oculta una reseña publicada y otro celular de la zona sincroniza
- **THEN** la reseña y sus fotos desaparecen de ese celular

### Requirement: Consulta sin conexión
Los datos públicos descargados SHALL poder consultarse sin conexión, y la app MUST indicar cuándo se
actualizaron por última vez.

#### Scenario: Directorio en modo avión
- **WHEN** el vecino abre el directorio en modo avión después de haber sincronizado
- **THEN** ve los servicios, las calificaciones y las reseñas descargados con "Actualizado hace X"

### Requirement: Acciones del directorio en la cola
Publicar, editar o retirar un servicio, escribir una reseña, dar o quitar un Visto Bueno y
denunciar SHALL guardarse primero en el celular, enviarse con su propia `Idempotency-Key` y mostrar
su estado de envío, igual que las acciones del muro.

#### Scenario: Reseña escrita sin señal
- **WHEN** el vecino escribe una reseña en modo avión
- **THEN** la ve al instante como "Guardado en tu celular" y se envía una sola vez al volver la conexión

#### Scenario: Rechazo definitivo
- **WHEN** el servidor responde 409 `resena_duplicada` a una reseña de la cola
- **THEN** la acción queda "No se pudo completar" con el motivo y las demás acciones se siguen enviando
