# mapas/region-offline Specification

## Purpose
Que el vecino vea el mapa de su distrito, los puntos de encuentro y lo cercano aunque no tenga internet, usando teselas cuya licencia permite el uso offline.

## Requirements

### Requirement: Fuente de teselas permitida
Las teselas SHALL provenir de un archivo PMTiles auto-hospedado generado con datos de OpenStreetMap o de un proveedor cuyos términos permitan expresamente la descarga offline. La app MUST NOT descargar regiones desde `tile.openstreetmap.org`.

#### Scenario: Revisión de la configuración
- **WHEN** se revisa el estilo del mapa de la app
- **THEN** todas sus fuentes apuntan a la CDN propia o al proveedor aprobado en el ADR

### Requirement: Descarga de la región del distrito
La app SHALL ofrecer descargar la región del distrito (zoom 10 a 15) solo con Wi-Fi por defecto, mostrando el progreso y el tamaño, y permitir cancelarla y borrarla.

#### Scenario: Descarga con Wi-Fi
- **WHEN** el vecino toca "Descargar mapa de mi distrito" conectado a Wi-Fi
- **THEN** ve el avance en porcentaje y megabytes hasta terminar

### Requirement: Mapa sin conexión
Con la región descargada, el mapa SHALL mostrarse y navegarse dentro del distrito en modo avión.

#### Scenario: Modo avión
- **WHEN** el vecino abre el mapa en modo avión después de descargarlo
- **THEN** ve las calles del distrito sin errores de carga

### Requirement: Atribución visible
El mapa SHALL mostrar siempre "© OpenStreetMap contributors", como exige la licencia ODbL.

#### Scenario: Cualquier pantalla con mapa
- **WHEN** se muestra un mapa
- **THEN** la atribución es visible y legible con letra grande
