# Spec Delta

## Purpose

Publicar en el muro debe ser tan rápido que nadie lo deje para después: máximo tres toques desde el inicio (sección 6).

## ADDED Requirements

### Requirement: Máximo tres toques
Publicar SHALL requerir como máximo tres toques desde el inicio: (1) botón "+", (2) tipo de publicación, (3) "Publicar" en un formulario mínimo con campos prellenados.

#### Scenario: Publicación rápida
- **WHEN** un vecino toca "+", elige "Presto" y toca "Publicar" con el título sugerido
- **THEN** la publicación queda guardada con exactamente tres toques

### Requirement: Formulario mínimo prellenado
El formulario SHALL sugerir categoría y título según el tipo, permitir dictado por voz y dejar opcionales la descripción y la ubicación aproximada.

#### Scenario: Tipo "Necesito"
- **WHEN** el vecino elige "Necesito"
- **THEN** el formulario aparece con una categoría sugerida y el cursor en el título

### Requirement: Guardado inmediato aunque no haya señal
Al tocar "Publicar" la app SHALL guardar la publicación en el celular, volver al muro y mostrarla marcada "Guardado en tu celular" aunque no haya conexión.

#### Scenario: Publicar en modo avión
- **WHEN** el vecino publica en modo avión
- **THEN** vuelve al muro y ve su publicación con el aviso de que todavía no se envió

### Requirement: Errores explicados antes de enviar
La app SHALL validar en el celular con las mismas reglas que el servidor y MUST explicar el problema en lenguaje simple junto al campo.

#### Scenario: Título muy corto
- **WHEN** el vecino intenta publicar con un título de dos letras
- **THEN** ve "El título debe tener entre 3 y 120 caracteres." junto al campo y no se encola nada
