# identidad/roles-y-confianza Specification

## Purpose
Aplicar en la API los niveles de confianza y los roles de la sección 5.5 y 9.1, para que cada acción la haga solo quien corresponde.

## Requirements

### Requirement: Autorización por nivel
Las rutas SHALL poder exigir un nivel de confianza mínimo; con nivel insuficiente la API MUST responder 403 `nivel_de_confianza_insuficiente` indicando el nivel requerido.

#### Scenario: Reseñar sin confirmar residencia
- **WHEN** un vecino nivel 0 intenta una acción que exige nivel 1
- **THEN** recibe 403 con `nivelRequerido` = 1

### Requirement: Autorización por rol
Las rutas operativas SHALL poder exigir un rol (coordinador, brigadista, moderador, administrador) y MUST verificarlo en el servidor aunque la app oculte el botón. Si declaran varios roles, SHALL admitir al vecino que tenga al menos uno; el rol `administrador` MUST NOT conceder otros roles implícitamente.

#### Scenario: Vecino sin rol llama a una ruta operativa
- **WHEN** un vecino sin rol de coordinador llama a una ruta de coordinación
- **THEN** la API responde 403

#### Scenario: Ruta con varios roles admitidos
- **WHEN** un vecino tiene uno de los roles declarados en la ruta
- **THEN** la API le permite continuar aunque no tenga los demás

#### Scenario: Administrador sin el rol operativo exigido
- **WHEN** un administrador llama a una ruta que exige el rol de brigadista y no lo tiene
- **THEN** la API responde 403 `rol_requerido`

### Requirement: Combinación y precedencia de restricciones
Si una ruta exige nivel y rol, el vecino SHALL cumplir ambos. La metadata declarada en un método MUST sobrescribir la metadata del mismo tipo declarada en su clase.

#### Scenario: Sobrescritura en un método
- **WHEN** un método declara un nivel o roles distintos de los de su clase
- **THEN** la autorización usa las restricciones del método

### Requirement: Cambios de nivel o rol con efecto rápido
Un cambio de nivel, rol o zona SHALL reflejarse a más tardar en la siguiente renovación del token de acceso o de sincronización.

#### Scenario: Se le retira el rol a un brigadista
- **WHEN** un administrador retira el rol de brigadista
- **THEN** su siguiente token ya no incluye el rol y sus streams operativos dejan de sincronizar

#### Scenario: Cambios antes de una sincronización
- **WHEN** cambian el nivel, los roles o la zona del vecino en la base y solicita nuevas credenciales de sincronización
- **THEN** el token nuevo incluye los valores actualizados
