# Lote D · Quechua y accesibilidad (Fase 3)

| Dato | Valor |
|---|---|
| Dificultad | ★ La más accesible para empezar |
| Área | `app/lib/l10n/`, `app/l10n.yaml`, `app/test/`, la consola web para sus textos |
| Change de OpenSpec | `fase-3-lote-d-quechua-y-accesibilidad` (se crea al abrir la fase) |
| Partes | 3 |

## Estado del lote

| Parte | Qué entrega | Estado | Responsable | PR |
|---|---|---|---|---|
| 1 | Quechua | Pendiente | Por asignar | — |
| 2 | Auditoría de accesibilidad y dictado por voz | Pendiente | Por asignar | — |
| 3 | Mejoras por métricas de uso | Pendiente | Por asignar | — |

Estados posibles: **Pendiente**, **En curso** o **Hecha** (integrada en `main`).

---

## Parte 1 · Quechua

- Con la comunidad y los aliados, elegir qué variedad del quechua se usa primero y quiénes revisan
  la traducción.
- `app_qu.arb` con todas las claves de `app_es.arb`, selector de idioma en la cuenta y una prueba
  que falle si una clave nueva no tiene traducción.
- Los textos que llegan de la CDN (tutorial y directorio de emergencia) también se publican en
  quechua.

## Parte 2 · Auditoría de accesibilidad y dictado por voz

- Auditoría WCAG 2.2 AA de los flujos principales con TalkBack y VoiceOver: publicar, buscar,
  reseñar, pedir ayuda y abrir el directorio de emergencia.
- Dictado por voz (`speech_to_text`) en todos los formularios de texto.
- Golden tests con texto grande para cada pantalla nueva desde la Fase 1.

## Parte 3 · Mejoras por métricas de uso

- Con las métricas anónimas de uso (embudos de publicar, buscar y pedir ayuda) y las pruebas con
  vecinos, priorizar y hacer las mejoras de experiencia que más ayudan.
- Cada mejora se mide antes y después y se registra en las evidencias.

## Fuera de alcance

Funciones nuevas del producto.
