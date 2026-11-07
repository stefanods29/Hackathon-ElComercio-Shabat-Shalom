# Spec Delta

## Purpose

Que los vecinos recomienden servicios y publicaciones por WhatsApp y otras redes, y que un enlace
abra la pantalla correcta de la app sin exponer datos personales (sección 6 de la arquitectura).

## ADDED Requirements

### Requirement: Compartir sin datos personales
El botón compartir de un servicio o una publicación SHALL generar un texto corto con un enlace
`https://<dominio>/s/<id>` o `/p/<id>`, y MUST NOT incluir teléfonos, nombres de vecinos ni
ubicaciones.

#### Scenario: Compartir un servicio
- **WHEN** el vecino comparte un servicio de gasfitería
- **THEN** el texto lleva el título del servicio y su enlace, sin el teléfono ni la ubicación del proveedor

### Requirement: Abrir la app desde un enlace
Un enlace verificado SHALL abrir en la app la pantalla del servicio o la publicación, pidiendo
iniciar sesión primero si hace falta.

#### Scenario: Enlace con la app instalada
- **WHEN** un vecino con la app instalada toca un enlace `/s/<id>`
- **THEN** la app abre el detalle de ese servicio

#### Scenario: Sin sesión
- **WHEN** el vecino toca el enlace sin haber iniciado sesión
- **THEN** la app le pide ingresar y después lo lleva al servicio

### Requirement: Sin la app instalada
Si la app no está instalada, el enlace SHALL abrir una página estática con los enlaces a las tiendas
y MUST NOT mostrar el contenido del servicio o la publicación.

#### Scenario: Celular sin la app
- **WHEN** alguien sin la app abre un enlace compartido
- **THEN** ve una página con los enlaces a las tiendas y ningún dato del contenido
