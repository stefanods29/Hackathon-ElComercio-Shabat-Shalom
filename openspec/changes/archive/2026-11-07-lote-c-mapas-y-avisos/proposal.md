# Proposal

## Why

La Fase 0 exige validar dos piezas del stack con riesgo propio: que los mapas del distrito
funcionen sin internet desde una fuente cuyos términos lo permitan (el servidor público de
OpenStreetMap lo prohíbe) y que los avisos lleguen por token de dispositivo y por tópico de zona
sin datos sensibles (secciones 3.4, 7.5 y 13.1). **Dueño: Lote C · Dificultad 3/5.**

## What Changes

- **Fuente de teselas** decidida con un ADR (decisión abierta 3, sección 13.3): archivo PMTiles
  auto-hospedado del distrito piloto (o proveedor con descarga offline permitida), servido por la
  CDN local con soporte de Range y atribución "© OpenStreetMap contributors".
- **Mapa en la app** con `maplibre_gl`: estilo propio, región del distrito descargable por Wi-Fi
  (zoom 10–15), progreso y tamaño medido en un Android de gama baja.
- **Módulo Notificaciones** en el backend: registro de dispositivos (token FCM), puerto
  `NotificationPort` con adaptador FCM y uno falso, envío por token y por tópico `zona-<id>`, y
  manejador del trabajo `notificaciones.enviar_aviso` que define el Lote B.
- **Avisos en la app** con `firebase_messaging`: permiso, registro del token, suscripción al tópico
  de su zona y apertura de la pantalla correcta tras autenticarse.

Fuera de alcance: SMS de respaldo para coordinadores (Fase 2), malla entre celulares (I+D).

## Capabilities

### New Capabilities
- `mapas/region-offline`: mapa del distrito disponible sin conexión desde una fuente permitida.
- `notificaciones/avisos-push`: avisos públicos por zona y personales por dispositivo.

### Modified Capabilities

## Impact

`app/lib/features/mapa/`, `app/lib/features/avisos/` (nuevo), `app/pubspec.yaml`
(`maplibre_gl`, `firebase_core`, `firebase_messaging`), configuración nativa en `app/android/` y
`app/ios/`, `backend/src/modules/notificaciones/`, `infra/cdn/`, `contracts/openapi.yaml`
(`POST /v1/dispositivos`).
