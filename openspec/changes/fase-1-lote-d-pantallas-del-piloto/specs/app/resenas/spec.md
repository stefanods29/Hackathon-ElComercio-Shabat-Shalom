# Spec Delta

## Purpose

Que un vecino reseñe un servicio con estrellas, comentario y fotos, dé su Visto Bueno y denuncie lo
que no corresponde, entendiendo siempre en qué estado está lo que hizo (secciones 5.5 y 6 de la
arquitectura).

## ADDED Requirements

### Requirement: Escribir una reseña
La pantalla de reseña SHALL ofrecer estrellas grandes, un comentario opcional con dictado por voz y
hasta 3 fotos, y quien la escribe MUST verla "En revisión" hasta que se publique.

#### Scenario: Reseña con dos fotos
- **WHEN** el vecino califica con 4 estrellas, escribe un comentario y agrega dos fotos
- **THEN** ve su reseña "Guardado en tu celular" y luego "En revisión" hasta que la moderación la publique

### Requirement: Estrellas accesibles
Cada estrella SHALL tener al menos 48 dp y una etiqueta que el lector de pantalla anuncie como
"N de 5 estrellas", sin depender del color.

#### Scenario: TalkBack en las estrellas
- **WHEN** el lector de pantalla recorre las estrellas con 3 elegidas
- **THEN** anuncia "3 de 5 estrellas" y cada estrella como un botón

### Requirement: Visto Bueno explicado
El botón Visto Bueno SHALL mostrar si el vecino ya lo dio y explicar en lenguaje simple para qué
sirve y que solo cuenta desde el nivel 2.

#### Scenario: Primer Visto Bueno
- **WHEN** un vecino de nivel 1 da su Visto Bueno
- **THEN** ve que quedó registrado y que contará cuando sea vecino verificado

### Requirement: Denunciar contenido
"Denunciar" SHALL estar disponible en publicaciones, reseñas, servicios y fotos, con un motivo de una
lista y la confirmación "Gracias, lo revisaremos".

#### Scenario: Denunciar una foto
- **WHEN** el vecino denuncia una foto con el motivo "Datos personales"
- **THEN** ve "Gracias, lo revisaremos" y la denuncia queda en la cola de envío

### Requirement: Rechazos explicados
La app SHALL explicar en lenguaje simple los rechazos `resena_duplicada`, `no_puedes_resenarte`,
`cuenta_muy_nueva`, `fuera_de_tu_zona` y `limite_diario_alcanzado`, con una alternativa.

#### Scenario: Segunda reseña
- **WHEN** la reseña recibe 409 `resena_duplicada`
- **THEN** el vecino ve "Ya reseñaste este servicio" y el acceso a su reseña anterior
