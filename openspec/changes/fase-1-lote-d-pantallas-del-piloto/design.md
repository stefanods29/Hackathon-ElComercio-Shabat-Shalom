# Design

## Context

Ver `proposal.md`. De la Fase 0 ya existen el sistema de diseño accesible (`AccessibleTheme`,
`LargeButton`, `NoticeCard`, modo sencillo), publicar en 3 toques, estados visibles, "Acciones por
revisar", el tutorial con modo práctica y las pantallas de cuenta. Patrón de pantalla:
`app/lib/features/solidaridad/` (`domain/` en Dart puro, `data/` con proveedores de Riverpod y
`presentation/` sin lógica de negocio). El Lote A define los puertos del directorio y la reputación
con sus dobles en memoria, `AuthRepository.changeZone` y `deleteAccount`, y la pantalla básica
`/emergencia` (`fase-1-lote-a-datos-offline-y-metricas`, decisiones 5, 7 y 9). El Lote C entrega
`PhotoPicker` y el botón compartir.

## Goals / Non-Goals

**Goals:**
- Pantallas que solo conocen puertos y proveedores: el Lote A cambia la implementación sin tocarlas.
- WCAG 2.2 AA: contraste, 48 dp, texto al 200 % sin cortes, etiquetas en español y el color nunca
  como única señal.
- Toda acción muestra su estado: "Guardado en tu celular", "Enviado" o "No se pudo completar".

**Non-Goals:**
- Repositorios reales, cola y limpieza del celular (Lote A), rutas del backend (Lote B) y subida de
  fotos (Lote C).

## Decisions

### 1. Rutas y flujo

```mermaid
flowchart LR
  H[Inicio / muro] -->|"Estoy en emergencia"| E[/emergencia/]
  H -->|Servicios cerca| D[/servicios/]
  D --> S[/servicios/:id/]
  S --> P[/proveedores/:id/]
  S --> R[/servicios/:id/resena/]
  H -->|"+"| T[/publicar/]
  T -->|Ofrezco un servicio| F[/publicar/servicio/]
  H --> C[/cuenta/]
  C --> M[/cuenta/mis-datos/]
  C --> N[/cuenta/niveles/]
  C --> Z[/elegir-zona/ cambio de zona]
```

- Rutas en español en `core/router/routes.dart`: `/servicios`, `/servicios/:id`,
  `/servicios/:id/resena`, `/proveedores/:id`, `/publicar/servicio`, `/cuenta/mis-datos` y
  `/cuenta/niveles`. `/emergencia` ya la crea el Lote A.
- "Ofrezco un servicio" se agrega como tipo en la grilla del botón "+", para conservar los 3 toques.

### 2. Datos de las pantallas

- Directorio y reputación: `serviceDirectoryRepositoryProvider` y `reputationRepositoryProvider`
  del Lote A. Las pruebas usan sus dobles en memoria.
- Estado de envío de cada acción: el mismo `SubmissionStatusChip` y "Acciones por revisar". La tabla
  de alternativas por `codigo` se amplía con `conflicto_de_version`, `resena_duplicada`,
  `no_puedes_resenarte`, `cuenta_muy_nueva`, `fuera_de_tu_zona`, `limite_diario_alcanzado` y
  `cuenta_suspendida`.
- Búsqueda local: la normalización sin tildes que define el Lote A en el dominio del directorio.
- Emergencia: el proveedor del directorio de emergencia del Lote A; `url_launcher` abre `tel:`.
- Privacidad: rutas de consentimientos, `GET /v1/yo/datos`, `PATCH /v1/yo` y `DELETE /v1/yo` (Lote
  B, parte 4) detrás de un puerto `PrivacyRepository` en `features/cuenta/domain/`, con su doble en
  memoria. La exportación se guarda como archivo JSON y se ofrece con la hoja de compartir del
  sistema.
- Tutorial: contenido en un JSON de la CDN validado y una copia como asset, con el mismo enfoque que
  el directorio de emergencia.

### 3. Textos y accesibilidad

- Todos los textos en `app_es.arb`, con claves en inglés. Ningún texto escrito directo en un widget.
- Pruebas de widgets con `textScaler` 2,0, `androidTapTargetGuideline`, `iOSTapTargetGuideline`,
  `labeledTapTargetGuideline` y `textContrastGuideline` en cada pantalla nueva.
- Modo sencillo: el directorio, la reseña y la emergencia usan los mismos widgets con parámetros.

### Puntos de contacto con otros lotes

| Con | Qué | Regla |
|---|---|---|
| A | Puertos del directorio y la reputación, `AuthRepository.changeZone` y `deleteAccount`, pantalla `/emergencia` y su proveedor | D usa los dobles; las interfaces no cambian sin acordarlo con A |
| B | Contrato y códigos de error de cada ruta | D muestra el motivo por el `codigo` estable |
| C | `PhotoPicker`, botón compartir y rutas `/s/:id` y `/p/:id` | C entrega los componentes; D revisa su accesibilidad |
| Todos | `core/router/router.dart`, `app_es.arb`, `pubspec.yaml`, permisos de `android/` e `ios/` | Cambios pequeños; un commit por tema |

## Risks / Trade-offs

- [Pantallas listas antes que los datos reales] → Se prueban con los dobles y el Lote A comprueba en
  la integración que funcionan sin cambios.
- [Un adulto mayor no entiende un rechazo] → Mensajes en lenguaje simple con una alternativa, y la
  prueba de usabilidad del criterio de salida.
- [Prometer ayuda que nadie garantiza] → Los mensajes de la sección 9.4 en la pantalla de emergencia
  y en el tutorial.
