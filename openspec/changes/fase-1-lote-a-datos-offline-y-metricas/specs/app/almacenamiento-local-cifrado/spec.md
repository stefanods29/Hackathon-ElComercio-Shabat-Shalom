# Spec Delta

## ADDED Requirements

### Requirement: Cambiar de zona limpia los datos de la zona anterior
Cuando el vecino cambia de zona, la app SHALL borrar del celular los datos públicos de la zona
anterior y sincronizar los de la nueva. Sus reseñas, sus Visto Bueno y sus publicaciones propias
MUST seguir disponibles en el celular.

#### Scenario: Vecino que se muda
- **WHEN** el vecino cambia de la zona piloto a la zona vecina
- **THEN** su celular ya no guarda servicios, reseñas ni publicaciones de la zona piloto ajenos a él

### Requirement: Cambio de zona sin acciones pendientes
La app MUST NOT cambiar de zona mientras haya acciones "Guardado en tu celular": explica que primero
deben enviarse, para que ninguna se pierda ni llegue a la zona equivocada.

#### Scenario: Acciones en la cola
- **WHEN** el vecino intenta cambiar de zona con dos acciones pendientes de envío
- **THEN** la app le explica que debe esperar a que se envíen y no cambia la zona

### Requirement: Borrar la cuenta borra todo el celular
Cuando el servidor confirma el borrado de la cuenta, la app SHALL borrar la base local, la caché de
datos sensibles, los archivos del vecino, su almacenamiento seguro y su token de avisos, y volver al
inicio de sesión.

#### Scenario: Derecho de cancelación
- **WHEN** el vecino confirma "Borrar mi cuenta" y el servidor lo acepta
- **THEN** al volver a abrir la app no queda ningún dato de esa cuenta en el celular

#### Scenario: Borrado sin conexión
- **WHEN** el vecino intenta borrar su cuenta sin conexión
- **THEN** la app explica que necesita conexión y no borra nada todavía

### Requirement: Fotos pendientes descartadas
Al cerrar sesión o borrar la cuenta, las fotos que todavía no se subieron SHALL eliminarse del
celular sin subirse.

#### Scenario: Cerrar sesión con una foto en cola
- **WHEN** el vecino cierra sesión con una foto de una reseña todavía sin subir
- **THEN** la foto se borra del celular y nunca llega al servidor
