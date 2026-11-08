# 0014 · Consola web de operación en Flutter web

**Estado:** propuesto el 7 de noviembre de 2026; se aprueba en la revisión de la parte 1 del Lote C
de la Fase 2.
**Dueño:** Lote C de la Fase 2 · Parte 1.
**Alcance:** sección 9.5 de la arquitectura y `consola/operacion` de OpenSpec.

## Contexto

La consola de operación es para coordinadores, brigadistas, moderadores y curadores. Funciona solo
en línea, usa la misma API con roles operativos y debe cumplir WCAG 2.2 AA (sección 9.5). La
arquitectura dejó abierta la tecnología: Flutter web, que reutiliza modelos y textos, o React.

Lo que ya existe:
- **App:** Flutter 3.47, con Riverpod, go_router, Dio, textos en ARB y un tema accesible.
- **Lote D de esta fase:** el tablero de emergencia, con los mismos patrones.
- **Backend:** NestJS en TypeScript.

## Opciones

| Criterio | Flutter web | React + TypeScript |
|---|---|---|
| Mantenimiento | Un solo lenguaje y los mismos patrones que la app y el Lote D; el equipo ya los conoce | Otro framework, otro gestor de estado y otro enrutador para el mismo equipo |
| Reutilización | Tema, `ProblemDetails`, convenciones de textos e idempotencia; MapLibre con la misma API | Ninguna directa; el modelo se duplica en TypeScript |
| Accesibilidad | Árbol de semántica de Flutter: hay que activarlo siempre y cuidar el foco y el orden | HTML nativo: los lectores de pantalla lo entienden sin trabajo extra |
| Tamaño | 2 a 3 MB en la primera carga (motor más app); luego queda en caché | Cientos de KB |
| Mapa | `maplibre_gl` con su implementación web (MapLibre GL JS) | MapLibre GL JS directo |

## Decisión

**Flutter web**, en un proyecto propio, `consola/`:

- **No depende del paquete `app/`.** `app/` trae plugins móviles (PowerSync con cifrado, cámara,
  ubicación) que no deben llegar al navegador. Lo poco que se reutiliza se copia.
- **La semántica se activa siempre** con `SemanticsBinding.instance.ensureSemantics()`. Todo
  control tiene etiqueta en español, el foco se ve y se puede recorrer con el teclado.
- **El tamaño se acepta:** es una herramienta de trabajo que se abre en una computadora con conexión,
  no en un celular de gama baja. Se mitiga con el *tree shaking* de íconos y la caché de larga
  duración de los recursos con hash.

## Consecuencias

- Cada pantalla nueva necesita su revisión con un lector de pantalla en el navegador (NVDA o
  VoiceOver), porque Flutter web no es HTML nativo.
- `flutter build web` entra a la CI con su propio flujo (`.github/workflows/consola.yml`, descrito
  en la integración del lote).
- Si la revisión de accesibilidad de la parte 2 no llega a WCAG 2.2 AA, este ADR se revisa y React
  pasa a ser la opción. Los puertos y el dominio de la consola no dependen del framework de vista.
