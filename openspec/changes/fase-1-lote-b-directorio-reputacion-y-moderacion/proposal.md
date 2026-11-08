# Proposal

## Why

El piloto necesita que los vecinos encuentren oficios y servicios cercanos con la confianza de sus
vecinos, que puedan reseñarlos y que todo contenido se pueda denunciar y ocultar. También necesita
una forma real de subir de nivel de confianza y cumplir la Ley 29733 (consentimiento y derechos
ARCO). Este lote construye en el backend los módulos Directorio, Reputación y Moderación y la
identidad del piloto (secciones 4.2, 5.3–5.5 y 10 de la arquitectura).
**Dueño: Lote B (por asignar) · Dificultad ★★★ · El Lote A revisa e integra cada entrega.**

## What Changes

- **Directorio:** categorías, perfil de proveedor y servicios con ubicación exacta privada, copia
  pública según el ADR 0010, concurrencia optimista y borrado lógico.
- **Búsqueda:** `GET /v1/servicios` por cercanía (PostGIS), categoría, texto tolerante a tildes y
  errores, y solo útiles en emergencia, con paginación por cursor y sin ubicaciones exactas.
- **Reputación:** reseñas con fotos (una por vecino y servicio, nadie se reseña a sí mismo),
  Visto Bueno, ranking bayesiano recalculado desde los hechos y antifraude básico.
- **Identidad del piloto:** nivel 1 por confirmación de residencia (ADR 0011) o a mano, nivel 2 por
  avales, cambio de zona con límite, consentimientos por finalidad y derechos ARCO (acceso,
  rectificación, cancelación y oposición).
- **Moderación:** denuncias, cadena de filtros, cola de casos para el rol `moderador`, decisiones
  que ocultan o restauran contenido de cualquier módulo y publicación de las reseñas en revisión.
- **BREAKING (contrato):** `PUT /v1/yo/zona` deja de responder siempre 409 `zona_ya_elegida` a
  quien ya tiene zona: permite cambiarla con un límite de tiempo.

Fuera de alcance: validación del DNI y nivel 3 (Fase 2 con aliados), módulo Emergencias (Fase 2),
consola web de moderación (Fase 2, Lote C), Valkey, réplicas y extracción de servicios (Fase 3),
subida y procesamiento de imágenes (Lote C de esta fase) y pantallas (Lote D de esta fase).

## Capabilities

### New Capabilities
- `directorio/servicios`: categorías, perfiles de proveedor y servicios, con sus reglas de dueño,
  versión, borrado y privacidad de la ubicación.
- `directorio/busqueda`: búsqueda de servicios por cercanía, categoría y texto.
- `reputacion/resenas-y-ranking`: reseñas, fotos de reseña, Visto Bueno, ranking y antifraude.
- `identidad/niveles-y-privacidad`: niveles 1 y 2, cambio de zona, consentimientos y derechos ARCO.
- `moderacion/denuncias`: denuncias, casos, decisiones de moderación y su efecto en el contenido.

### Modified Capabilities
- `identidad/inicio-de-sesion`: "Elegir la zona" ahora permite cambiar de zona con un límite y
  reinicia el nivel de confianza.

## Impact

- `backend/src/modules/directorio/`, `reputacion/`, `moderacion/` (hoy esqueletos), `identidad/` y
  `solidaridad/` (columna `oculta_en` y manejo de su ocultamiento).
- `contracts/openapi.yaml`: rutas nuevas de los cuatro temas, primero el contrato en cada parte.
- Migraciones de los esquemas `directorio`, `reputacion`, `moderacion`, `identidad` y `solidaridad`;
  tablas públicas agregadas a la publicación `powersync` con `SELECT` para `powersync_rol`.
- `backend/src/workers/` (ranking, moderación, borrado de cuenta), `scripts/seed-data.ts`
  (categorías y servicios de demostración), `.env.example` y `docs/grafos/`.
- `docs/adr/0011-confirmacion-de-residencia.md` (nuevo).
- Puntos de contacto: columnas públicas que leen los Sync Streams del Lote A, `archivoId` de las
  fotos del Lote C y códigos de error que muestran las pantallas del Lote D.
