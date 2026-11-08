# Tasks

## 1. Parte 1 · Datos públicos del piloto en el celular

- [ ] 1.1 Escribir `docs/adr/0010-precision-de-la-ubicacion-publica.md` (3 decimales, ubicación exacta solo con consentimiento del proveedor, el muro no necesita migración) y agregarlo al índice de ADRs; verificar que el índice lo enlaza y que el equipo lo aprueba en la revisión de la parte
- [x] 1.2 Agregar a `infra/powersync/sync-config.yaml` los streams `categorias`, `servicios_de_mi_zona`, `proveedores_de_mi_zona`, `resenas_publicadas`, `fotos_de_resenas_publicadas`, `mis_resenas` y `mis_vistos_buenos`, y el filtro `oculta_en IS NULL` en los streams del muro; verificar con `npm run sync:validate`
- [x] 1.3 Pruebas de acceso en `backend/test/sync/datos-publicos.spec.ts` (otra zona sin filas, reseña en revisión solo para su autor, ocultos fuera de todo bucket, ninguna columna privada en streams automáticos) e incluir `test/sync/**/*.spec.ts` en `vitest.config.ts`; verificar con `npm test`
- [x] 1.4 Puertos de dominio, entidades y dobles en memoria de `features/directorio/` y `features/reputacion/` con sus proveedores de Riverpod; verificar con pruebas unitarias (búsqueda sin tildes, filtro de emergencia, estados de una reseña)
- [x] 1.5 Tablas locales nuevas en `core/sync/local_schema.dart`, columna `envios.optimista` y repositorios `PowerSyncServiceDirectoryRepository` y `PowerSyncReputationRepository` (lectura reactiva y escritura optimista con comando y envío en una transacción); verificar con pruebas sobre una base PowerSync local, incluida la lectura sin conexión
- [x] 1.6 Conector de subida con los tipos nuevos (método y ruta por tipo, `Idempotency-Key` del comando, rechazos sin bloquear la cola); verificar con pruebas de HTTP falso para cada tipo y para un 409 `resena_duplicada`
- [x] 1.7 Sobreescribir los proveedores del directorio y la reputación en `AuthenticatedApp` y en la sesión de desarrollo; verificar con una prueba que las pantallas reciben los repositorios reales
- [ ] 1.8 Compilar y depurar: `npm run verify` en el backend, `tool/verify.sh` en la app y CI en verde

## 2. Parte 2 · Directorio de emergencia sin conexión

- [ ] 2.1 Escribir `contracts/directorio-emergencia.schema.json` (archivo de distrito e índice) y documentarlo en `contracts/README.md`; verificar que el esquema es JSON válido y que las pruebas de 2.2 y 2.3 lo usan
- [x] 2.2 Publicar `infra/cdn/publico/emergencia/lince-demo.json` (116, 105 y 106 con fuente oficial y fecha) y `indice.json`, con un script de `infra/cdn` que recalcula el índice; verificar con `npm test` en `infra/cdn` que cada hash coincide
- [ ] 2.3 Capa de datos en `features/emergencias/data/`: índice, descarga sin token, SHA-256, validación, reemplazo atómico, revisión como máximo diaria y umbrales de antigüedad por tipo; verificar con pruebas unitarias (descarga corrupta, sin cambios, dato viejo) y con una prueba que valida los archivos publicados
- [ ] 2.4 Copia de respaldo `assets/emergencia/respaldo.json` y pantalla básica `/emergencia` con fuente y fecha de cada dato; verificar con una prueba de widgets sin red que muestra solo el respaldo, con texto al 200 % y objetivos de 48 dp
- [ ] 2.5 Prueba en un celular en modo avión; registrar el resultado en `docs/fase-1/evidencias/directorio-emergencia.md`
- [ ] 2.6 Compilar y depurar: `tool/verify.sh`, `npm test` en `infra/cdn` y CI en verde

## 3. Parte 3 · Métricas de sincronización

- [ ] 3.1 Agregar `POST /v1/telemetria/sincronizacion` y la sección `sincronizacion` de las métricas operativas a `contracts/openapi.yaml`; verificar con `npx @redocly/cli lint contracts/openapi.yaml`
- [ ] 3.2 Migración `compartido.telemetria_sincronizacion`, esquema Zod estricto y ruta `@Idempotent()` en `shared/observability`, sin guardar la identidad; verificar con pruebas unitarias y de integración (guarda contadores, 400 con un campo extra, 401 sin sesión, sin columnas de usuario)
- [ ] 3.3 Resumen de los últimos 7 días en `GET /v1/operacion/metricas`; verificar con una prueba de integración como administrador y como vecino (403)
- [ ] 3.4 Agregador de contadores en la app (cola, p50 y p95 hasta "Enviado", rechazos por código, tiempo desde la última sincronización, errores de conexión); verificar con pruebas unitarias
- [ ] 3.5 Envío diario anónimo con `Idempotency-Key`, versión de la app y sistema; verificar con una prueba de HTTP falso que el cuerpo solo trae los campos del contrato y que no se repite el mismo día
- [ ] 3.6 Revisión de privacidad de cada campo y guía de lectura de las métricas para el Lote C en `docs/fase-1/evidencias/sincronizacion.md`; verificar que ningún campo identifica a una persona
- [ ] 3.7 Compilar y depurar: `npm run verify`, `npm run test:integration`, `tool/verify.sh` y CI en verde

## 4. Parte 4 · Zona, cuenta y fotos pendientes

- [ ] 4.1 `AuthRepository.changeZone` y `deleteAccount` en el puerto, el doble en memoria y `HttpAuthRepository` (contrato de B, parte 4); verificar con pruebas de HTTP falso, incluidos los rechazos y la falta de conexión
- [ ] 4.2 Cambio de zona solo con la cola vacía, con purga y reconexión a los streams de la zona nueva; verificar con una prueba que no quedan filas ajenas de la zona anterior
- [ ] 4.3 Borrado de cuenta: baja del token de avisos, `DELETE /v1/yo`, purga de la base, la caché sensible, el almacenamiento seguro y los archivos; verificar con una prueba que no queda ningún dato de la cuenta
- [ ] 4.4 Puerto `PendingPhotoPurger` (implementación vacía hasta C2) llamado al cerrar sesión y al borrar la cuenta; verificar con una prueba con un purgador falso
- [ ] 4.5 Prueba en un celular real (Android; iPhone o excepción autorizada) de los tres casos; registrar la evidencia en `docs/fase-1/evidencias/privacidad.md`
- [ ] 4.6 Compilar y depurar: `tool/verify.sh` y CI en verde

## 5. Parte 5 · Piloto en campo

- [ ] 5.1 Confirmar con el equipo el barrio, los flujos (decisión 13.3.1) y los números de los criterios de salida; registrarlos en `docs/fase-1/criterios-de-salida.md`
- [ ] 5.2 Preparar el piloto: material de consentimiento, instalación por las betas del Lote C y canal de soporte; registrar la preparación en `docs/fase-1/evidencias/piloto.md`
- [ ] 5.3 Revisar cada semana, durante al menos 4 semanas, las métricas, la cola de moderación y los incidentes; completar `piloto.md`, `sincronizacion.md`, `datos-publicos.md` y `directorio-emergencia.md` sin datos personales
- [ ] 5.4 Completar con los celulares del piloto las pruebas de campo de la Fase 0 (matriz adversa de la cola, segundo plano, conflicto con dos celulares, mapa sin conexión y recepción de avisos) y registrarlas en `docs/fase-0/evidencias/`
- [ ] 5.5 Compilar y depurar la versión que se distribuye al piloto (CI en verde)

## 6. Parte 6 · Integración de la Fase 1

- [ ] 6.1 Integrar las entregas aprobadas de B, C y D con la autorización del equipo; verificar `npm run verify`, `npm run test:integration`, `tool/verify.sh`, `openspec validate --all --strict` y Redocly en la rama integrada
- [ ] 6.2 Probar el flujo completo (registro, consentimiento, confirmación de residencia, búsqueda sin señal, reseña con foto guardada sin conexión y enviada después, denuncia, ocultamiento, desaparición en otro celular y directorio de emergencia en modo avión); registrar el resultado en `docs/fase-1/evidencias/piloto.md`
- [ ] 6.3 Compilar y depurar todo con la CI en verde en `main` y desplegar staging y producción con el Lote C

## Workflow follow-up

- Archivar los cuatro changes de la Fase 1 cuando el Lote A apruebe la última entrega y la CI esté en verde.
- Marcar la Fase 1 como hecha en `docs/hoja-de-ruta.md`.
