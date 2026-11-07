# Avisos · implementación y verificación local

Fecha: 2026-11-07. Estado: C3 y C4 implementadas en código, con integraciones externas pendientes.
Esta evidencia no equivale a recepción real en un teléfono ni a aprobación del lote.

## Implementado

- Contrato y API autenticada de registro/baja, con idempotencia y sin tokens en las respuestas.
- Migración privada: dispositivos, avisos y entregas por destinatario, fuera de PowerSync.
- Plantillas genéricas, adaptadores Fake/FCM y validación estricta del trabajo.
- Favor tomado → identificador estable → trabajo singleton → entrega con control de duplicados.
- Reintentos parciales, instalación reasignada, baja e identificador inválido.
- App con Firebase opcional, permiso explícito, cola segura, refresco, tópico y cierre de sesión.
- Apertura de publicaciones locales; destino pendiente conservado antes de autenticarse.
- Ajustes de avisos y ayuda cuando el permiso está denegado, sin bloquear el uso de la app.

## Resultados reproducibles

| Comprobación | Resultado local |
|---|---|
| Backend: tipos, lint, formato, fronteras, Sync Streams, pruebas y build | `npm run verify` |
| Pruebas unitarias de backend | 40 aprobadas; incluye plantillas, FCM simulado y configuración |
| Integración con PostgreSQL 18.6 / PostGIS 3.6.2 | 24 aprobadas; 7 de avisos |
| Pruebas Flutter | 76 aprobadas; 10 nuevas de avisos/detalle |
| Análisis Flutter | Sin incidencias antes del último ajuste de integración; comprobación final en curso |
| Contrato OpenAPI | Válido; 2 advertencias preexistentes en salud y JWKS |
| OpenSpec estricto | 10 elementos aprobados |
| APK Android sin archivos Firebase privados | Compilación final en curso |

El trabajo repetido, también en paralelo, produce **un envío** en el adaptador falso. Si el
segundo dispositivo falla, el primer envío completado no se repite al reintentar. El adaptador
FCM se prueba con el SDK simulado; estas pruebas no se presentan como entrega real de Firebase.

El FID de Firebase Messaging 17 se registra en el campo REST opaco `token`. Admin 14.5 envía
con `fid`. Referencias oficiales:
[registro Flutter](https://firebase.google.com/docs/cloud-messaging/flutter/get-started),
[recepción y apertura](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages),
[envío Admin](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).

## Pendientes de integración y aceptación

1. **A:** conectar `pushCredentialsProvider` a la sesión real y llamar `signOut()` antes de
   retirar sus credenciales, conservando las claves de recuperación que sigan pendientes.
2. **B4:** integrar el relay outbox y el worker persistente; unificar `JobHandlerRegistry`.
   Actualmente se prueba con el arranque manual y `InMemoryJobQueue.drain()` permitido por la guía.
3. **B3:** incorporar la ruta operativa de coordinador, protegida por rol y confianza nivel 3.
   Hasta entonces el tópico se verifica desde el trabajo interno con texto público genérico.
   El título/texto escrito por coordinador todavía no está disponible.
4. **Firebase / Apple:** proyecto, archivos nativos privados, cuenta de servicio, firma,
   capacidades Push Notifications y APNs. La app conserva `ENABLE_PUSH=false` por defecto.
5. **Dispositivos:** no hay Android disponible según lo indicado por el usuario; tampoco se
   ha probado un iPhone. Faltan capturas de aviso personal, tópico y pantalla bloqueada genérica
   en ambos sistemas. No se han inventado capturas ni resultados físicos.
6. **Revisión:** CI remoto, PRs, aprobación del ADR y aceptación de las cuatro partes.

La caída entre la aceptación de Firebase y la confirmación en PostgreSQL puede repetir una
entrega: FCM no ofrece una clave de idempotencia de envío. Véase el README del módulo para las
garantías concretas. La misma limitación debe constar al revisar la integración con el worker.
