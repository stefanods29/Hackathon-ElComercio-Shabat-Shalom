# Proposal

## Why

El piloto de la Fase 1 solo funciona si el directorio de servicios, las reseñas y el directorio de
emergencia están en el celular aunque no haya señal, sin exponer la ubicación exacta de nadie, y
si el equipo puede saber cada semana si la sincronización está sana. Este lote lleva esos datos al
celular, mide la sincronización, deja el celular limpio al cambiar de zona o borrar la cuenta,
corre el piloto e integra la fase (secciones 3.4, 7.3, 8, 11 y 12 de la arquitectura).
**Dueño: Lote A (JDiazD33) · Dificultad ★★★★ · Además revisa e integra las entregas de B, C y D.**

## What Changes

- **ADR 0010 · Precisión de la ubicación pública:** la copia pública de una ubicación se redondea
  a 3 decimales (unos 110 m); un proveedor con local a la calle puede mostrar la ubicación exacta
  de su local solo con un consentimiento explícito. Los streams publican únicamente esa copia.
- **Sync Streams de datos públicos:** categorías (globales), servicios y proveedores de la zona,
  reseñas publicadas y sus fotos, mis reseñas y mis Visto Bueno. Solo columnas públicas; lo
  borrado u oculto sale del celular en la siguiente sincronización. Los streams del muro también
  excluyen lo ocultado por moderación.
- **Repositorios del directorio y la reputación en la app:** puertos de dominio con dobles en
  memoria (para las pantallas del Lote D) e implementaciones sobre PowerSync. El conector de
  subida aprende las operaciones nuevas (servicio, reseña, Visto Bueno y denuncia), cada una con
  su `Idempotency-Key`.
- **Directorio de emergencia sin conexión:** contrato JSON Schema, un archivo por distrito en la
  CDN con un índice de versión y hash, descarga y validación en la app, copia de respaldo con los
  números 116, 105 y 106, aviso de "posiblemente desactualizado" y una pantalla básica en
  `/emergencia` que el Lote D completa.
- **Métricas de sincronización:** contadores agregados y anónimos en la app, la ruta
  `POST /v1/telemetria/sincronizacion` y su resumen en las métricas operativas para el tablero del
  Lote C.
- **Zona, cuenta y fotos pendientes:** cambiar de zona o borrar la cuenta deja el celular limpio
  (base local, caché sensible, archivos, almacenamiento seguro, token de avisos y fotos sin subir).
- **Piloto en campo** de al menos 4 semanas con sus evidencias, incluidas las pruebas de campo que
  la Fase 0 dejó para el piloto.
- **Integración de la Fase 1:** flujo completo con las entregas de B, C y D, CI, despliegue con el
  Lote C y archivo de los changes de la fase.

Supuestos que se registran hasta que el equipo los confirme: el barrio piloto es la zona sembrada
de Lince (demo) y entran todos los flujos de la sección 12 (decisión 13.3.1); los números de los
criterios de salida siguen siendo un ejemplo y se fijan al preparar el piloto (parte 5).

Fuera de alcance: pedidos de ayuda, tablero humanitario y modo operativo con PIN (Fase 2);
sincronización a escala y varias zonas por persona (Fase 3); pantallas finales del directorio, las
reseñas, la emergencia y la privacidad (Lote D de esta fase); tablas y rutas del directorio, la
reputación y la moderación (Lote B de esta fase).

## Capabilities

### New Capabilities
- `sincronizacion/datos-publicos`: qué datos públicos del directorio y la reputación llegan a cada
  celular, con qué precisión, cómo se escriben desde la cola y cuándo salen del celular.
- `emergencias/directorio-offline`: directorio de emergencia disponible sin señal, con su fuente,
  su fecha de verificación y el aviso de antigüedad.
- `plataforma/metricas-de-sincronizacion`: métricas agregadas y anónimas de la cola y la
  sincronización, y su consulta por el equipo.

### Modified Capabilities
- `sincronizacion/datos-por-zona`: una publicación ocultada por moderación también sale de los
  streams y de los celulares.
- `app/almacenamiento-local-cifrado`: el cambio de zona y el borrado de la cuenta limpian el
  celular, y las fotos pendientes se descartan sin subirse.

## Impact

- `infra/powersync/sync-config.yaml` y pruebas de acceso de los streams en `backend/test/sync/`.
- `docs/adr/0010-precision-de-la-ubicacion-publica.md` y el índice de ADRs.
- `contracts/openapi.yaml` (telemetría de sincronización) y
  `contracts/directorio-emergencia.schema.json` (nuevo).
- `backend/src/shared/observability/` y una migración del esquema `compartido`.
- `infra/cdn/publico/emergencia/` y sus scripts de índice en `infra/cdn/`.
- `app/lib/core/sync/`, `app/lib/features/directorio/`, `app/lib/features/reputacion/`,
  `app/lib/features/emergencias/`, `app/lib/features/cuenta/`, `app/lib/authenticated_app.dart`,
  `app/pubspec.yaml` y `app/lib/l10n/app_es.arb`.
- `docs/fase-1/evidencias/` (piloto, sincronización, datos públicos y directorio de emergencia).
- Depende del contrato y las tablas del Lote B (partes 1, 3, 4 y 5), del almacenamiento de fotos
  del Lote C (partes 1 y 2) y de staging del Lote C (parte 4).
