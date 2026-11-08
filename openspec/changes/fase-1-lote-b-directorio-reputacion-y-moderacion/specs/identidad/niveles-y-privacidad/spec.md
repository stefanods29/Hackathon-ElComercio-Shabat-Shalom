# Spec Delta

## Purpose

Que un vecino real pueda subir a los niveles 1 y 2 de confianza durante el piloto y ejercer sus
derechos sobre sus datos personales, según la Ley 29733 y el D.S. 016-2024-JUS (secciones 5.5 y 10
de la arquitectura y ADR 0011).

## ADDED Requirements

### Requirement: Residencia confirmada por presencia
Con su consentimiento, el celular SHALL poder informar una vez al día solo si estuvo dentro de su
zona, sin coordenadas. Con presencia en 3 días distintos dentro de 14 días, el vecino MUST subir al
nivel 1 y se registra `identidad.residencia_confirmada`.

#### Scenario: Tres días en dos semanas
- **WHEN** un vecino de nivel 0 informa presencia en su zona tres días distintos en una semana
- **THEN** sube al nivel 1 y su siguiente token lo refleja

#### Scenario: Sin consentimiento
- **WHEN** un vecino que no aceptó la confirmación por presencia informa su presencia
- **THEN** la API responde 403 `consentimiento_requerido` y no guarda nada

### Requirement: Residencia confirmada a mano
Un moderador SHALL poder confirmar a mano la residencia de un vecino, con motivo y auditoría, para
quien no quiere o no puede usar la presencia.

#### Scenario: Junta vecinal confirma
- **WHEN** un moderador confirma la residencia de un vecino con el motivo "validado por la junta vecinal"
- **THEN** el vecino sube al nivel 1 y queda registrado quién lo confirmó y cuándo

### Requirement: Nivel 2 por avales
`POST /v1/vecinos/{id}/aval` SHALL registrar el aval de un vecino de nivel 2 o más de la misma zona,
nunca a sí mismo, de forma idempotente. Con 2 avales distintos el vecino MUST subir al nivel 2.

#### Scenario: Dos avales
- **WHEN** dos vecinos verificados de la zona avalan a un vecino de nivel 1
- **THEN** el vecino sube al nivel 2

#### Scenario: Aval a sí mismo
- **WHEN** un vecino intenta avalarse
- **THEN** la API responde 403 `no_puedes_avalarte`

### Requirement: Cambio de zona con límite
Un vecino SHALL poder cambiar de zona como máximo una vez cada 30 días. Al cambiar, su nivel MUST
volver a 0 hasta confirmar la nueva residencia.

#### Scenario: Cambio antes de tiempo
- **WHEN** un vecino que cambió de zona hace 10 días intenta cambiarla otra vez
- **THEN** la API responde 409 `cambio_de_zona_muy_pronto` con la fecha desde la que podrá hacerlo

### Requirement: Consentimiento por finalidad
`GET` y `POST /v1/yo/consentimientos` SHALL registrar la aceptación o el rechazo de cada finalidad,
con la versión del texto aceptado. Una finalidad opcional rechazada MUST impedir el tratamiento que
cubre.

#### Scenario: Rechaza la confirmación por presencia
- **WHEN** el vecino acepta el uso del servicio pero rechaza la confirmación por presencia
- **THEN** puede usar la app y la API no acepta informes de presencia suyos

#### Scenario: Texto desactualizado
- **WHEN** el celular envía una aceptación con una versión anterior del texto
- **THEN** la API responde 409 `version_de_consentimiento_desactualizada`

### Requirement: Acceso y rectificación
`GET /v1/yo/datos` SHALL exportar todos los datos personales del vecino que guardan los módulos, y
`PATCH /v1/yo` MUST permitir rectificar su nombre visible.

#### Scenario: Exportar mis datos
- **WHEN** el vecino pide sus datos
- **THEN** recibe su perfil, su zona, sus consentimientos, sus publicaciones, sus servicios, sus reseñas, sus Visto Bueno y sus denuncias

### Requirement: Cancelación de la cuenta
`DELETE /v1/yo` SHALL revocar de inmediato todas las sesiones del vecino y programar un trabajo que
borra sus datos personales y anonimiza su contenido público. Tras el trabajo, su teléfono y su
nombre MUST NOT quedar en ninguna tabla.

#### Scenario: Borrar mi cuenta
- **WHEN** el vecino borra su cuenta
- **THEN** la API responde 202, sus sesiones dejan de servir y, al terminar el trabajo, su teléfono y su nombre ya no están en la base

### Requirement: Oposición
La oposición a una finalidad opcional SHALL registrarse como un rechazo de su consentimiento y MUST
detener ese tratamiento desde ese momento.

#### Scenario: Se opone a la presencia
- **WHEN** un vecino de nivel 1 retira su consentimiento a la confirmación por presencia
- **THEN** la API deja de aceptar sus informes de presencia y conserva su nivel ya confirmado
