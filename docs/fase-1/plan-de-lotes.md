# Plan de lotes · Fase 1 (piloto en un barrio)

**Entra** cuando la Fase 0 cumple sus criterios de salida, o cuando el equipo acepta por escrito
los que queden abiertos. **Sale** cuando el barrio piloto usa la app de verdad, la moderación
funciona y las métricas de sincronización están sanas ([criterios](criterios-de-salida.md)).

Antes de abrir la fase el equipo decide qué flujos entran al piloto y en qué barrio (decisión
13.3.1). Este plan supone todos los de la sección 12: directorio con Visto Bueno, muro de favores,
directorio de emergencia offline (solo lectura), tutorial y moderación.

## Los 4 lotes

| Lote | Partes | Qué entrega |
|---|---|---|
| **A · Datos offline y métricas** ★★★★ | 6 | Streams públicos del directorio y la reputación, directorio de emergencia sin conexión, métricas de sincronización, cierre de cuenta y zona, piloto en campo e integración |
| **B · Directorio, reputación y moderación** ★★★ | 5 | Módulos Directorio y Reputación, búsqueda por cercanía y texto, ranking bayesiano, confirmación de residencia, consentimiento y derechos ARCO, y módulo Moderación |
| **C · Fotos, entornos y observabilidad** ★★ | 5 | Módulo Media, fotos en la app, compartir por WhatsApp, entornos dev · staging · prod con OpenTofu y OpenTelemetry + Sentry |
| **D · Pantallas del piloto** ★ | 5 | Directorio, perfil de proveedor, reseñas con fotos, denuncias, botón "Estoy en emergencia", consentimiento y "Mis datos" |

## Cómo encajan

| Punto de contacto | Quién lo define | Quién lo usa | Mientras tanto |
|---|---|---|---|
| Rutas de Directorio, Reputación, Moderación e Identidad en `contracts/openapi.yaml` | B (primero el contrato, en el PR inicial de cada parte) | A (conector de subida), C (consola en la Fase 2), D | D trabaja con repositorios en memoria |
| Tablas públicas y precisión de la ubicación | A (parte 1, ADR) con B | B guarda la copia pública; D la muestra | Datos sembrados |
| Directorio de emergencia (`contracts/directorio-emergencia.schema.json`) | A (parte 2) | D (parte 4) y C (CDN) | JSON de ejemplo en `infra/cdn/publico/emergencia/` |
| Archivos y fotos (`POST /v1/archivos`) | C (parte 1) | D (reseñas) y B (moderación de imágenes) | Fotos falsas en memoria |
| Eventos `reputacion.*` y `moderacion.*` en el outbox | B | B (workers), C (avisos) | — |
| Métricas de sincronización | A (parte 3) | C (tableros, parte 5) | Registro local |
| Staging | C (parte 4) | Todos; B corre ahí la capacidad pendiente de la Fase 0 | Docker Compose local |

Se puede adelantar la parte 4 del Lote C para cerrar en staging los criterios de capacidad y
despliegue de la Fase 0 (acción 7 de la [revisión del 7 de noviembre](../fase-0/revision-2026-11-07.md)).

## Hitos

| Hito | Se cumple cuando… |
|---|---|
| **H1 · Contratos** | Contrato de B1–B5 y C1, esquema del directorio de emergencia y ADR de precisión de ubicación aprobados |
| **H2 · Directorio offline** | A1–A2, B1–B3, C1–C2 y D1–D3 aprobadas: se busca, se reseña con foto y se ve sin señal |
| **H3 · Piloto listo** | B4–B5, C3–C5, D4–D5 y A3–A4 aprobadas; staging y producción desplegados |
| **H4 · Salida de la Fase 1** | A5 y A6 aprobadas y los criterios de salida con evidencia |

## Changes de OpenSpec (creados al abrir la fase)

| Lote | Change | Capacidades nuevas o modificadas |
|---|---|---|
| A | `fase-1-lote-a-datos-offline-y-metricas` | `sincronizacion/datos-publicos`, `emergencias/directorio-offline`, `plataforma/metricas-de-sincronizacion` |
| B | `fase-1-lote-b-directorio-reputacion-y-moderacion` | `directorio/servicios`, `directorio/busqueda`, `reputacion/resenas-y-ranking`, `identidad/niveles-y-privacidad`, `moderacion/denuncias` |
| C | `fase-1-lote-c-fotos-entornos-y-observabilidad` | `media/archivos`, `app/fotos`, `plataforma/entornos`, `plataforma/observabilidad` |
| D | `fase-1-lote-d-pantallas-del-piloto` | `app/directorio`, `app/resenas`, `app/emergencia-basica`, `app/privacidad` |
