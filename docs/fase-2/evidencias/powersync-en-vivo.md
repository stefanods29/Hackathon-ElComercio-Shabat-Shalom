# PowerSync en vivo · Parte 2 del Lote A

## Entorno y alcance

Base de la rama: `4fb7761a52d2762911dbfb02ea5b7c9e25781d26`.
Laboratorio del 8 de noviembre de 2026: Docker Engine 29.6.1, PostgreSQL 18 con PostGIS 3.6,
PowerSync Service 1.28.1, Node 26.13.0 y cliente `@powersync/node` 1.3.0 con SQLite real.
La composición adicional fija la versión del servicio para repetir la prueba. La imagen usada
tiene el digest `sha256:4955ebd8218d076f23296750f658c2973ce1dcd2ba49a6c7a7c3320acf97325c`.

El runner crea cuentas, sesiones, zona y pedido ficticios, sirve una API completa de prueba en
el puerto 3001 con clave efímera y solicita credenciales a `GET /v1/sync/credenciales`.
Los clientes se conectan al servicio real, con bases locales independientes. Cada suscripción
se conserva y debe figurar sincronizada con sus parámetros exactos. Después de cada cambio,
`requestCheckpoint().waitForSync()` confirma la aplicación de un checkpoint del origen en cada
cliente. Una actualización pública posterior al cambio añade una comprobación positiva de
frescura. No se decide un resultado negativo por una espera fija. El protocolo se describe en
la [documentación del servicio](https://github.com/powersync-ja/powersync-service/blob/main/docs/replication/06-checkpoints.md).

El runner compara los parámetros de las suscripciones por valor: su orden en el JSON puede
cambiar entre el cliente y el servicio. Las primeras repeticiones descubrieron que esperar solo
el marcador público era insuficiente para comprobar suscripciones recién abiertas; por eso la
versión final exige también el estado de la suscripción y el checkpoint del origen.

Se eligió Node para ejecutar esta prueba sin emuladores, con el mismo runner de la integración
del backend y el SDK oficial. La prueba local de `AssignedCaseCache` se ejecuta aparte: usa
transporte simulado y bases cifradas reales, y comprueba memoria, archivo y clave. Esa purga
Flutter no equivale a probar teléfonos reales contra el servicio.

## Repetición

Desde la raíz, en un laboratorio limpio y con Node 26:

```sh
docker compose -p vecinal-f2-live -f infra/docker-compose.yml -f infra/compose.powersync-live.yml up -d --wait
cd backend
npm ci
npm rebuild better-sqlite3
npm run dev:keys
npm run db:migrate
npm run db:seed
```

`better-sqlite3` necesita compilador C/C++ y las herramientas nativas de Node si no hay binario
precompilado; la reconstrucción explícita prepara el cliente SQLite con el mismo Node que ejecuta
la prueba. `dev:keys` crea un `.env` privado. La configuración opcional de Firebase debe omitirse si no
se usa; una cadena vacía no es un identificador válido. La base de ese archivo debe ser la
misma que replica el servicio. Para ejecutar el runner, definir `DATABASE_URL` con la conexión
local de laboratorio y `POWERSYNC_LIVE_TEST=1`, y correr:

```sh
npm run test:sync:live
npm run verify
npm run test:integration
```

Para la integración, definir también `DATABASE_URL_ADMIN`: crea una base temporal distinta y
la elimina al finalizar. La prueba en vivo utiliza únicamente sus propios registros en la base
replicada. No ejecutar simultáneamente dos runners en vivo: comparten el puerto 3001 y el JWKS.
Ninguna clave, credencial ni contenido de las filas debe copiarse al informe.

Desde `app/`, `bash tool/verify.sh`; desde la raíz, `openspec validate --all --strict`.

## Resultados

`POWERSYNC_LIVE_TEST=1 npm run test:sync:live`: dos ejecuciones consecutivas de la versión
final, ambas `1 passed (1)`, con duración total de 71,09 s y 112,39 s. Las nueve comprobaciones
imprimieron `PASS` en ambas ejecuciones:

| Caso | Resultado |
|---|---|
| Sin asignación activa | Cero filas de resumen |
| Asignación sin permiso, cuenta ajena y otra sesión de la misma cuenta | Cero filas; el permiso propio sí entrega el resumen |
| Antes de `en_camino` | Cero ubicaciones; la API rechaza abrir el alcance exacto |
| En `en_camino` | La proyección exacta llega solo a la sesión con permiso exacto; el autor no recibe ubicaciones |
| Streams automáticos y publicación | Sin filas privadas de emergencias; autor comprobado antes de abrir `mi_pedido`; `detalles_pedidos` fuera de publicación |
| Alcances intercambiados | Resumen no concede ubicación; exacta no concede resumen |
| Reasignación controlada entre dos cuentas | El primero pierde ambas filas; el segundo no recibe datos hasta abrir sus propios permisos |
| Salida de `en_camino` y cierre | Ningún operador conserva resumen ni ubicación |
| Auditoría | Cuatro aperturas, una por cada par actor/alcance, con fecha dentro de la ejecución y sin columnas de contenido |

La comprobación previa del rol de replicación devolvió 15 tablas publicadas, todas legibles por
`powersync_rol`, y cero publicaciones de `detalles_pedidos`.

`npm run verify`: tipos, lint, formato, fronteras, configuración de streams sin advertencias,
246 pruebas y compilación aprobados. El lint conserva seis advertencias anteriores de ordenación
en las pruebas de directorio y reputación; no se añadieron advertencias.

`openspec validate --all --strict`: 30 elementos aprobados, cero fallos.

La integración en Windows dio 198/199: la única prueba fallida exige permisos Unix `0600`
para un archivo y Windows devuelve `0666`. La repetición en Linux con
`node:26.13.0-bookworm` dio **25 archivos y 199 pruebas aprobados**, en 468,10 s. No se cambió
la prueba ni se rebajó ese requisito.

La suite completa de Flutter en Ubuntu 26.04.1 aprobó `284` pruebas y omitió una prueba previa
en la rama de referencias visuales. Incluye todas las pruebas de `AssignedCaseCache`; ese archivo
es idéntico en ambas ramas (objeto `89ff0097db86cbfd2eb265dda9e4e4212e4c9b29`).
Comprueba purga al retirar ubicación, reasignar, cerrar, vencer y salir: memoria, archivos y claves.

Pendiente registrar la verificación completa de Flutter y la CI de esta rama.

## Límites

La API permite reasignar en `visto` y no permite hacerlo durante `en_camino`. La prueba distingue
el flujo permitido por HTTP de un cambio controlado de asignaciones en PostgreSQL, usado solo
para comprobar que ambos streams retiran las filas del cliente anterior. No cambia la máquina
de estados ni las decisiones de integración.

Los celulares reales, las capturas y la señal débil corresponden a la prueba de campo A 5.2.
La estabilidad en GitHub Actions del servicio completo todavía no se ha demostrado; por ello
no se agrega un job de PowerSync a la CI con esta evidencia local.
