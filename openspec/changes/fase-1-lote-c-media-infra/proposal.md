## Why

El piloto necesita fotos ligeras y sin ubicación incrustada, una forma de compartir contenido
público y entornos reproducibles con monitoreo que respete la privacidad. Dueño: Lote C.

## What Changes

- Módulo Media con subida firmada privada, miniaturas, cuotas y procesamiento recuperable.
- Fotos cifradas y cola en la app; compartir desde el selector del teléfono.
- OpenTelemetry y Sentry opcionales, con datos técnicos mínimos.
- Propuesta OpenTofu dev/staging/prod, sin despliegue.

## Capabilities

### New Capabilities
- `media/fotos-seguras`: selección, subida y procesamiento de imágenes privadas.
- `app/compartir-publicaciones`: compartir contenido público confirmado.
- `plataforma/observabilidad-privada`: monitoreo técnico sin contenido personal.
- `plataforma/entornos`: configuración reproducible por entorno.

### Modified Capabilities

## Impact

Contrato OpenAPI, módulos Media y shared, app, paquetes, infraestructura y CI.
Quedan fuera: identidad/SMS (B), pantallas finales de reseñas/perfiles (D), moderación y datos
públicos del directorio (B/A), consola operativa (Fase 2), despliegue real y costos sin presupuesto.
