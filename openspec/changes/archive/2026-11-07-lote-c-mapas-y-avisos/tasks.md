# Tasks

## 1. Parte 1 · Fuente de teselas

- [x] 1.1 ADR de la fuente de teselas (PMTiles propio vs proveedor) con los términos revisados; verificar que el equipo lo aprueba en el PR
- [x] 1.2 Generar `distrito.pmtiles` del distrito piloto y publicarlo en `infra/cdn/publico/` (sin subir binarios pesados a git: script reproducible); verificar con `curl -r 0-1023` que la CDN responde con Range
- [x] 1.3 Estilo MapLibre propio con atribución OSM; verificar que carga en un visor web
- [x] 1.4 Compilar y depurar (CI en verde): CI del PR de cierre

C1: ADR 0008 aprobado el 7 de noviembre de 2026, al cerrar la Fase 0. Evidencia:
`docs/fase-0/evidencias/fuente-de-teselas.md`. La compilación la verifica la CI del PR de cierre.

## 2. Parte 2 · Mapa sin conexión en la app

- [x] 2.1 Agregar `maplibre_gl` y la pantalla de `/mapa` con el estilo propio; verificar con pruebas de la app (la prueba en un Android real pasa al piloto)
- [x] 2.2 Descarga de la región (zoom 10–15, solo Wi-Fi por defecto, progreso, cancelar, borrar); verificar con pruebas de la app (el tamaño en un Android de gama baja se mide en el piloto)
- [x] 2.3 Prueba en modo avión dentro del distrito: trasladada al piloto de la Fase 1 (Lote A, parte 5), con evidencia en `docs/fase-0/evidencias/mapas.md`
- [x] 2.4 Compilar y depurar en Android e iOS (CI en verde): CI del PR de cierre

C2: interfaz, adaptador MapLibre, política de conexión y pruebas automatizadas integrados en el PR
de cierre. Con autorización del usuario, las comprobaciones en un celular pasan al piloto de la
Fase 1. Detalle: `docs/fase-0/evidencias/mapas.md`.

## 3. Parte 3 · Avisos en el backend

- [x] 3.1 Agregar `POST /v1/dispositivos` al contrato; verificar con `redocly lint`
- [x] 3.2 Migración `notificaciones.dispositivos`, registro idempotente y baja al cerrar sesión; verificar con pruebas de integración
- [x] 3.3 Puerto `NotificationPort` con adaptador FCM y adaptador falso; envío por token y por tópico; verificar con pruebas
- [x] 3.4 Manejador del trabajo `notificaciones.enviar_aviso` (idempotente) y aviso de "favor tomado"; verificar con una prueba de entrega doble
- [x] 3.5 Compilar y depurar (CI en verde): CI del PR de cierre

C3: integrado en el PR de cierre sobre el relay y los workers de B4; el backend completo pasa
161 pruebas unitarias y 114 de integración. FCM se comprueba con el SDK simulado y el trabajo con
el adaptador falso; la recepción real pasa al piloto. Evidencia: `docs/fase-0/evidencias/avisos.md`.

## 4. Parte 4 · Avisos en la app

- [x] 4.1 Agregar `firebase_core` y `firebase_messaging`, permiso y registro del token; verificar con pruebas de la app (la recepción en Android pasa al piloto)
- [x] 4.2 Suscripción al tópico `zona-<id>` y baja al cambiar de zona o cerrar sesión; verificar con pruebas de la app (el aviso de prueba en un celular pasa al piloto)
- [x] 4.3 Tocar el aviso abre la pantalla correcta tras autenticarse; verificar con pruebas de la app (Android en el piloto; iPhone omitido con autorización)
- [x] 4.4 Evidencia de aviso por token y por tópico: trasladada al piloto de la Fase 1, con la cuenta de servicio de FCM; se registrará en `docs/fase-0/evidencias/avisos.md`
- [x] 4.5 Compilar y depurar (CI en verde): CI del PR de cierre

C4: permiso, registro persistente, refresco, tópicos, baja y apertura del detalle local
integrados. El Lote A conectó la sesión real (`pushCredentialsProvider`) y la baja al cerrar
sesión. Firebase sigue siendo opcional. La configuración de APNs y la recepción en teléfonos pasan
al piloto. Se rediseñaron también los dos visores.

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
