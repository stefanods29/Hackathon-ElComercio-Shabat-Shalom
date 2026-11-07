# Tasks

## 1. Parte 1 · Fuente de teselas

- [ ] 1.1 ADR de la fuente de teselas (PMTiles propio vs proveedor) con los términos revisados; verificar que el equipo lo aprueba en el PR
- [x] 1.2 Generar `distrito.pmtiles` del distrito piloto y publicarlo en `infra/cdn/publico/` (sin subir binarios pesados a git: script reproducible); verificar con `curl -r 0-1023` que la CDN responde con Range
- [x] 1.3 Estilo MapLibre propio con atribución OSM; verificar que carga en un visor web
- [ ] 1.4 Compilar y depurar (CI en verde)

Avance local de C1: ADR 0008 redactado (1.1 pendiente de aprobación); pruebas y comprobación
HTTP/visual realizadas (1.4 pendiente de CI). Evidencia: `docs/fase-0/evidencias/fuente-de-teselas.md`.

## 2. Parte 2 · Mapa sin conexión en la app

- [ ] 2.1 Agregar `maplibre_gl` y la pantalla de `/mapa` con el estilo propio; verificar en un Android real
- [ ] 2.2 Descarga de la región (zoom 10–15, solo Wi-Fi por defecto, progreso, cancelar, borrar); verificar el tamaño en un Android de gama baja y documentarlo
- [ ] 2.3 Prueba en modo avión dentro del distrito; dejar evidencia en `docs/fase-0/evidencias/mapas.md`
- [ ] 2.4 Compilar y depurar en Android e iOS (CI en verde)

Avance local de C2: interfaz, adaptador MapLibre, política de conexión y pruebas automatizadas
implementados. Las tareas siguen abiertas porque exigen dispositivo real, evidencia de modo
avión y validación Android/iOS. Detalle: `docs/fase-0/evidencias/mapas.md`.

## 3. Parte 3 · Avisos en el backend

- [x] 3.1 Agregar `POST /v1/dispositivos` al contrato; verificar con `redocly lint`
- [x] 3.2 Migración `notificaciones.dispositivos`, registro idempotente y baja al cerrar sesión; verificar con pruebas de integración
- [x] 3.3 Puerto `NotificationPort` con adaptador FCM y adaptador falso; envío por token y por tópico; verificar con pruebas
- [x] 3.4 Manejador del trabajo `notificaciones.enviar_aviso` (idempotente) y aviso de "favor tomado"; verificar con una prueba de entrega doble
- [ ] 3.5 Compilar y depurar (CI en verde)

Avance local de C3: 40 pruebas unitarias y 24 de integración aprobadas con PostgreSQL/PostGIS.
Contrato válido. FCM se comprueba con el SDK simulado y el trabajo con el adaptador falso; falta
la recepción real y la integración del relay/worker B4. La ruta de coordinador y su texto público
dependen de B3, según el punto de contacto de la guía. Evidencia: `docs/fase-0/evidencias/avisos.md`.

## 4. Parte 4 · Avisos en la app

- [ ] 4.1 Agregar `firebase_core` y `firebase_messaging`, permiso y registro del token; verificar en Android
- [ ] 4.2 Suscripción al tópico `zona-<id>` y baja al cambiar de zona o cerrar sesión; verificar con un aviso de prueba
- [ ] 4.3 Tocar el aviso abre la pantalla correcta tras autenticarse; verificar en Android e iPhone
- [ ] 4.4 Evidencia de aviso por token y por tópico en `docs/fase-0/evidencias/avisos.md`
- [ ] 4.5 Compilar y depurar (CI en verde)

Avance local de C4: permiso, registro persistente, refresco, tópicos, baja y apertura del detalle
local implementados; 76 pruebas Flutter aprobadas. Firebase es opcional. Las tareas siguen
abiertas por la sesión real del Lote A, configuración Firebase/APNs, recepción en teléfonos,
compilación iOS y CI. No hay evidencia física disponible. Se rediseñaron también los dos visores.

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
