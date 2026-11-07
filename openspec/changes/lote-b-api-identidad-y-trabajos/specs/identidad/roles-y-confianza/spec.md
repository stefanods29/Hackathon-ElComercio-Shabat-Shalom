# Spec Delta

## Purpose

Aplicar en la API los niveles de confianza y los roles de la sección 5.5 y 9.1, para que cada acción la haga solo quien corresponde.

## ADDED Requirements

### Requirement: Autorización por nivel
Las rutas SHALL poder exigir un nivel de confianza mínimo; con nivel insuficiente la API MUST responder 403 `nivel_de_confianza_insuficiente` indicando el nivel requerido.

#### Scenario: Reseñar sin confirmar residencia
- **WHEN** un vecino nivel 0 intenta una acción que exige nivel 1
- **THEN** recibe 403 con `nivelRequerido` = 1

### Requirement: Autorización por rol
Las rutas operativas SHALL poder exigir un rol (coordinador, brigadista, moderador, administrador) y MUST verificarlo en el servidor aunque la app oculte el botón.

#### Scenario: Vecino sin rol llama a una ruta operativa
- **WHEN** un vecino sin rol de coordinador llama a una ruta de coordinación
- **THEN** la API responde 403

### Requirement: Cambios de nivel o rol con efecto rápido
Un cambio de nivel, rol o zona SHALL reflejarse a más tardar en la siguiente renovación del token de acceso o de sincronización.

#### Scenario: Se le retira el rol a un brigadista
- **WHEN** un administrador retira el rol de brigadista
- **THEN** su siguiente token ya no incluye el rol y sus streams operativos dejan de sincronizar
