# Lote C · Zonas, borde y costos (Fase 3)

| Dato | Valor |
|---|---|
| Dificultad | ★★ Media |
| Área | `backend/scripts/`, `infra/cdn/`, `infra/tofu/`, herramientas de teselas y del directorio de emergencia |
| Change de OpenSpec | `fase-3-lote-c-zonas-borde-y-costos` (se crea al abrir la fase) |
| Partes | 3 |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Más zonas y distritos | Pendiente | Por asignar | — |
| 2 | Borde y recuperación ante desastres | Pendiente | Por asignar | — |
| 3 | Costos por etapa | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## Parte 1 · Más zonas y distritos

- Proceso repetible para dar de alta un distrito: polígonos de sus zonas (o celdas H3), teselas
  PMTiles con la fuente elegida en la Fase 0, directorio de emergencia del distrito y aliados para
  su regla de cobertura.
- Script de alta y verificación (límites válidos, sin solapes, tamaño de teselas aceptable para
  gama baja).

## Parte 2 · Borde y recuperación ante desastres

- CDN + WAF + límites de tasa delante del balanceador (por ejemplo Cloudflare), con reglas de caché
  para las teselas, el directorio de emergencia y el contenido del tutorial.
- Varias zonas de disponibilidad y un plan de recuperación ante desastres con un RTO y un RPO
  acordados, más un simulacro de recuperación documentado.

## Parte 3 · Costos por etapa

- Presupuesto por etapa (decisión 13.3.5) y tablero de costos por usuario activo, con alertas.
- Control del gasto en SMS de respaldo (Fase 2) y del costo de PowerSync y de la base de datos (por
  ejemplo, la replicación lógica que impide escalar a cero, sección 11).

## Fuera de alcance

Cambios en la app y en el modelo de datos que no pida el alta de distritos.
