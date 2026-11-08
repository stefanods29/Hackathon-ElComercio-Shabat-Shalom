## Why

La consola y el tablero necesitan el módulo Emergencias de las secciones 7–9. El Lote B de la
Fase 2 implementa las cinco partes sobre su entrega de Fase 1. El trabajo se autoriza como
desarrollo, sin compilar ni ejecutar pruebas; no declara cumplidos los requisitos humanos del piloto.

## What Changes

- Contrato de eventos, cobertura, pedidos, estados, asignaciones, turnos y grupos.
- Escalamiento persistente, recursos con frescura y verificación y agregados con supresión.
- Habilitaciones operativas con revisión humana, auditoría y cierre con anonimización.
- Detalles y coordenadas fuera de la publicación de PowerSync; acceso privado bajo demanda.
- Puertos para Identidad y alertas oficiales; eventos de integración para A/C/D.

## Capabilities

### New Capabilities
- `emergencias/operacion`: cobertura, eventos y turnos.
- `emergencias/pedidos`: estados, permisos, asignaciones y escalamiento.
- `emergencias/recursos`: frescura, verificación y agregados.
- `emergencias/privacidad-operativa`: habilitaciones, auditoría y anonimización.

## Impact

Backend, contrato OpenAPI, configuración y documentación. No incluye consola, sincronización
móvil, biometría, proveedor SMS, despliegue ni acreditación de alianzas o tiempos reales.
