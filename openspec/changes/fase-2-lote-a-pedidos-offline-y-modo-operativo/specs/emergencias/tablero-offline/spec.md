# Spec Delta

## Purpose

Mantener disponibles los recursos críticos y el panorama público de la zona cuando se corta la conexión.

## ADDED Requirements

### Requirement: Agregados anónimos por celda

El tablero SHALL mostrar solo agregados por celda y tipo de necesidad de la zona autorizada. El servidor MUST excluir de la publicación los grupos de menos de tres pedidos. Los datos descargados MUST NOT incluir identificadores de pedidos, ubicaciones exactas ni detalles individuales.

#### Scenario: Grupos por debajo del umbral

- **WHEN** el servidor publica dos grupos del mismo tipo con dos y tres pedidos respectivamente
- **THEN** el celular recibe solo el agregado del grupo de tres, sin filas que identifiquen a quienes pidieron ayuda

### Requirement: Recursos descargados con su frescura

La app SHALL permitir consultar sin conexión los recursos ya descargados e indicar cuándo fueron reportados. SHALL marcarlos como posiblemente desactualizados al superar el umbral configurado para su tipo. Los datos de fuente oficial SHALL mostrar su fuente y fecha de verificación.

#### Scenario: El vecino consulta un recurso antiguo sin señal

- **WHEN** abre en modo avión un recurso cuyo reporte superó su umbral
- **THEN** ve la copia descargada, su antigüedad y la indicación de que pudo cambiar

### Requirement: Prioridad de datos críticos

En modo emergencia la app SHALL priorizar la sincronización de datos críticos y desactivar la carga de imágenes.

#### Scenario: Vuelve la señal con tráfico pendiente

- **WHEN** se recupera la conexión con el modo emergencia activo y hay datos ordinarios y críticos pendientes
- **THEN** la app prioriza los datos críticos y mantiene desactivada la carga de imágenes
