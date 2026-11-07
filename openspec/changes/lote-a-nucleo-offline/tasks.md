# Tasks

## 1. Parte 1 · PowerSync de punta a punta

- [x] 1.1 Levantar `infra/` (`docker compose up -d`), la API y la semilla; verificar en los logs de PowerSync que replica `identidad.zonas` y `solidaridad.publicaciones`
- [ ] 1.2 Agregar `powersync` 2.x a la app y definir el esquema local (zonas, publicaciones, comandos insert-only, envíos local-only); verificar con una prueba que el esquema abre
- [ ] 1.3 Implementar el conector (`fetchCredentials` con `GET /v1/sync/credenciales`, renovación antes de vencer); verificar con una prueba con HTTP falso
- [ ] 1.4 Implementar `SyncService` sobre PowerSync (conectado, última sincronización, pendientes) y sobreescribir su proveedor; verificar en un Android real que llegan las publicaciones de la zona
- [ ] 1.5 Compilar y depurar: `flutter analyze`, `flutter test` y CI en verde

## 2. Parte 2 · Cifrado local y purga

- [ ] 2.1 Generar la clave aleatoria en `SecureStore` y abrir la base con `EncryptionOptions` (hooks `sqlite3mc`); verificar que la base no abre con una clave distinta
- [ ] 2.2 Cerrar sesión: `disconnectAndClear`, borrar la clave y volver al inicio; verificar con una prueba que no queda ningún dato
- [ ] 2.3 Caducidad local de datos sensibles con reloj inyectable; verificar con una prueba sin conexión
- [ ] 2.4 Sesión revocada (respuesta 401 de credenciales tras revocar) → borrar base local; verificar con una prueba
- [ ] 2.5 Conectar el `AuthRepository` real a las pantallas del Lote D: tokens en `SecureStore`, `getToken` con renovación serializada (`/v1/auth/refrescar`) y cierre de sesión (API, `disconnectAndWipeLocalData` y baja del token de avisos); verificar con pruebas con HTTP falso
- [ ] 2.6 Compilar y depurar en Android e iOS (CI en verde)

## 3. Parte 3 · Cola de subida con estados, reintentos y rechazos

- [ ] 3.1 `PowerSyncPostRepository`: lecturas reactivas del muro desde SQLite; verificar con pruebas
- [ ] 3.2 Publicar y tomar favor: cambio optimista + comando + envío en una sola transacción local; verificar con pruebas
- [ ] 3.3 `uploadData`: comando → endpoint con su `Idempotency-Key`, clasificación con `classifyResponse`, rechazo definitivo con `complete()` y reversión; verificar con pruebas contra la API local
- [ ] 3.4 "Acciones por revisar" (`watchActionsToReview`) con el motivo del servidor; verificar con una prueba de conflicto entre dos vecinos
- [ ] 3.5 Sobreescribir `postRepositoryProvider` con la implementación real; verificar que las pantallas del Lote D funcionan sin cambios
- [ ] 3.6 Compilar y depurar (CI en verde)

## 4. Parte 4 · Datos sensibles bajo demanda

- [ ] 4.1 Migraciones mínimas `emergencias.pedidos_ayuda` y `emergencias.asignaciones` (publicación y SELECT solo para `powersync_rol`); verificar con `npm run test:integration`
- [ ] 4.2 Stream bajo demanda `caso_asignado` en `sync-config.yaml`; verificar con `npm run sync:validate`
- [ ] 4.3 Pruebas automatizadas de acceso (no asignado = 0 filas; asignado = solo su caso); verificar que fallan si se agrega un stream automático sensible
- [ ] 4.4 Revocación: al reasignar, el detalle se borra del celular anterior; verificar en dispositivo real
- [ ] 4.5 Compilar y depurar (CI en verde)

## 5. Parte 5 · Pruebas de campo (sección 13.1)

- [ ] 5.1 Prueba de 500 operaciones (modo avión, señal débil, cierre forzado, reinicio, batería baja) en Android de gama baja e iPhone; verificar 0 pérdidas y 0 duplicados con conteos en el servidor y dejar el informe en `docs/fase-0/evidencias/`
- [ ] 5.2 Medir la sincronización en segundo plano en iOS y Android y documentarla; verificar que la UI no promete inmediatez
- [ ] 5.3 Conflicto con dos celulares sin conexión; verificar que el segundo ve el motivo y una alternativa (pantalla del Lote D)
- [ ] 5.4 Purga en línea y sin conexión; verificar con evidencia en dispositivo

## 6. Parte 6 · Integración de la Fase 0

- [ ] 6.1 Integrar en `main` las entregas aprobadas de los Lotes B, C y D y correr el flujo completo (OTP → muro offline → tomar favor → aviso → mapa offline); verificar con el checklist de `docs/fase-0/criterios-de-salida.md`
- [ ] 6.2 Compilar y depurar todo (backend, app Android e iOS) con CI en verde en `main`

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
- Con los criterios de salida cumplidos, planificar la Fase 1 con la misma estructura de lotes.
