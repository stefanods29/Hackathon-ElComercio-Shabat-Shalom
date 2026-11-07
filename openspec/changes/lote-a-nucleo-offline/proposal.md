# Proposal

## Why

Es la pieza más riesgosa de la arquitectura: si la cola offline pierde o duplica acciones, o si un
dato sensible llega al celular equivocado, el producto falla justo cuando más se necesita.
Este lote valida los supuestos más críticos de la sección 13.1 antes de construir encima.
**Dueño: Lote A (stefanods29) · Dificultad 5/5 · Además integra las entregas de B, C y D.**

## What Changes

- Motor de sincronización real en el celular con **PowerSync 2.x**: Sync Streams por zona,
  credenciales desde `GET /v1/sync/credenciales` y estado de sincronización para la UI.
- **SQLite cifrado** (`EncryptionOptions`, SQLite3MultipleCiphers) con clave aleatoria en
  Keychain/Keystore; borrado total al cerrar sesión; caducidad local de datos sensibles.
- **Cola de subida** (`uploadData`) que traduce cada acción a su endpoint con su
  `Idempotency-Key`, aplica la máquina de estados de envío, reintenta con espera exponencial y
  manda los rechazos definitivos a "acciones por revisar" sin bloquear el resto de la cola.
- Implementación real de `PostRepository` (reemplaza el doble en memoria).
- **Datos sensibles bajo demanda**: tablas mínimas de `emergencias` para validar que solo el
  brigadista asignado recibe el detalle y que se borra al terminar la asignación.
- Pruebas de campo de la sección 13.1 (500 operaciones sin pérdidas ni duplicados, sincronización
  en segundo plano, conflictos, purga) en un Android de gama baja y un iPhone.
- Integración final de la Fase 0: el flujo completo con lo entregado por B, C y D.

Fuera de alcance: tablero humanitario y pedidos de ayuda completos (Fase 2), malla entre
celulares (I+D), consola web (Fase 2).

## Capabilities

### New Capabilities
- `sincronizacion/cola-de-subida`: acciones offline persistentes, sin pérdidas ni duplicados.
- `sincronizacion/datos-sensibles-bajo-demanda`: detalle sensible solo para quien está asignado.
- `app/almacenamiento-local-cifrado`: base local cifrada, purga y caducidad.

### Modified Capabilities

## Impact

`app/lib/core/sync/`, `app/lib/features/solidaridad/data/`, `app/lib/features/emergencias/`,
`app/pubspec.yaml` (paquete `powersync`), `infra/powersync/`, `backend/src/modules/emergencias/`
(solo tablas mínimas y su stream). Sección 13.1 completa como criterio de salida de la Fase 0.
