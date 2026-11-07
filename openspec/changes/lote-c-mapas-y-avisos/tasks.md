# Tasks

## 1. Parte 1 · Fuente de teselas

- [ ] 1.1 ADR de la fuente de teselas (PMTiles propio vs proveedor) con los términos revisados; verificar que el equipo lo aprueba en el PR
- [ ] 1.2 Generar `distrito.pmtiles` del distrito piloto y publicarlo en `infra/cdn/publico/` (sin subir binarios pesados a git: script reproducible); verificar con `curl -r 0-1023` que la CDN responde con Range
- [ ] 1.3 Estilo MapLibre propio con atribución OSM; verificar que carga en un visor web
- [ ] 1.4 Compilar y depurar (CI en verde)

## 2. Parte 2 · Mapa sin conexión en la app

- [ ] 2.1 Agregar `maplibre_gl` y la pantalla de `/mapa` con el estilo propio; verificar en un Android real
- [ ] 2.2 Descarga de la región (zoom 10–15, solo Wi-Fi por defecto, progreso, cancelar, borrar); verificar el tamaño en un Android de gama baja y documentarlo
- [ ] 2.3 Prueba en modo avión dentro del distrito; dejar evidencia en `docs/fase-0/evidencias/mapas.md`
- [ ] 2.4 Compilar y depurar en Android e iOS (CI en verde)

## 3. Parte 3 · Avisos en el backend

- [ ] 3.1 Agregar `POST /v1/dispositivos` al contrato; verificar con `redocly lint`
- [ ] 3.2 Migración `notificaciones.dispositivos`, registro idempotente y baja al cerrar sesión; verificar con pruebas de integración
- [ ] 3.3 Puerto `NotificationPort` con adaptador FCM y adaptador falso; envío por token y por tópico; verificar con pruebas
- [ ] 3.4 Manejador del trabajo `notificaciones.enviar_aviso` (idempotente) y aviso de "favor tomado"; verificar con una prueba de entrega doble
- [ ] 3.5 Compilar y depurar (CI en verde)

## 4. Parte 4 · Avisos en la app

- [ ] 4.1 Agregar `firebase_core` y `firebase_messaging`, permiso y registro del token; verificar en Android
- [ ] 4.2 Suscripción al tópico `zona-<id>` y baja al cambiar de zona o cerrar sesión; verificar con un aviso de prueba
- [ ] 4.3 Tocar el aviso abre la pantalla correcta tras autenticarse; verificar en Android e iPhone
- [ ] 4.4 Evidencia de aviso por token y por tópico en `docs/fase-0/evidencias/avisos.md`
- [ ] 4.5 Compilar y depurar (CI en verde)

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
