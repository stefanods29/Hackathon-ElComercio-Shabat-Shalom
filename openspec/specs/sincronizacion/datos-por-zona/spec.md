# sincronizacion/datos-por-zona Specification

## Purpose
Definir qué datos públicos descarga cada celular para funcionar sin conexión, según la zona del vecino y sin exponer datos de otras zonas ni datos sensibles.

## Requirements

### Requirement: Datos públicos de la zona
Al conectarse, el celular SHALL recibir automáticamente su zona (nombre y distrito) y las publicaciones vigentes del muro de su zona, según el claim `zona` del token de sincronización.

#### Scenario: Vecino de la zona piloto
- **WHEN** un vecino de la zona piloto conecta su celular
- **THEN** recibe las publicaciones vigentes de esa zona y ninguna de otra zona

### Requirement: Lo propio del vecino
El celular SHALL recibir también las publicaciones que el propio vecino creó, aunque sean de otra zona.

#### Scenario: Vecino que se mudó
- **WHEN** un vecino cambia de zona
- **THEN** sigue viendo en su celular las publicaciones que él hizo antes

### Requirement: Minimización de lo replicado
Los Sync Streams MUST NOT enviar polígonos de zonas ni columnas de ubicación precisa, y las tablas sensibles MUST NOT estar en streams de suscripción automática.

#### Scenario: Revisión de la configuración
- **WHEN** se valida `infra/powersync/sync-config.yaml`
- **THEN** solo seleccionan columnas públicas y aproximadas, y ningún stream automático lee tablas sensibles

### Requirement: Publicaciones eliminadas
Una publicación con borrado lógico SHALL dejar de pertenecer a los streams y desaparecer de los celulares en la siguiente sincronización.

#### Scenario: Publicación retirada por moderación
- **WHEN** se marca `eliminado_en` en una publicación
- **THEN** los celulares la borran de su base local al sincronizar
