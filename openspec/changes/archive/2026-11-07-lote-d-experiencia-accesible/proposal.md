# Proposal

## Why

La app la usarán vecinos con celulares económicos y personas mayores, a veces bajo estrés. La
arquitectura pide publicar en máximo 3 toques, estados siempre visibles y accesibilidad WCAG 2.2 AA
(sección 6). Este lote construye esa experiencia sobre los dobles de los cimientos, en paralelo
con el motor de sincronización del Lote A. **Dueño: Lote D · Dificultad 2/5.**

## What Changes

- **Sistema de diseño accesible**: tema con contraste AA verificado, objetivos de 48 dp, texto
  escalable al 200 % sin cortes, lector de pantalla, ícono + texto, "modo sencillo".
- **Publicar en 3 toques**: "+" → tipo → formulario mínimo prellenado + "Publicar"; se guarda al
  instante en el celular aunque no haya señal.
- **Estados visibles**: "Guardado en tu celular" destacado, "Actualizado hace X", aviso sin
  conexión y bandeja de "acciones por revisar" con el motivo del rechazo y una alternativa.
- **Tutorial** interactivo sobre la pantalla real con "modo práctica" (no publica nada).
- **Inicio de sesión, zona y cuenta**: teléfono y código, "Elige tu zona" y "Mi cuenta" (cerrar
  sesión y teléfono perdido), sobre un doble de `AuthRepository` que el Lote A conecta a la API
  del Lote B.
- Textos en archivos de idioma (es-PE) listos para agregar quechua en la Fase 3; golden tests
  con letra grande.

Fuera de alcance: directorio de emergencia y botón "Estoy en emergencia" (Fase 1), tablero
humanitario (Fase 2), quechua (Fase 3).

## Capabilities

### New Capabilities
- `app/accesibilidad`: reglas de accesibilidad que cumple toda pantalla.
- `app/publicar-en-tres-toques`: flujo de publicación más corto posible.
- `app/visibilidad-de-estados`: el vecino siempre sabe qué se envió, qué no y qué tan frescos son los datos.
- `app/inicio-de-sesion-y-cuenta`: entrar, elegir la zona y controlar la cuenta sin ayuda.
- `app/tutorial`: aprender a usar la app sin miedo a equivocarse.

### Modified Capabilities

## Impact

`app/lib/core/theme/`, `app/lib/core/ui/`, `app/lib/features/publicar/`,
`app/lib/features/onboarding/`, `app/lib/features/cuenta/` (nuevo), `app/lib/features/solidaridad/presentation/`, `app/lib/l10n/`,
`app/test/` (widget y golden tests), `app/pubspec.yaml` (`showcaseview`).
