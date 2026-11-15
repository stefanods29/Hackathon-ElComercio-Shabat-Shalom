# Encargo para stefanods29: PowerSync en vivo y referencias visuales en Linux

**Agente recomendado: Opus 5.5.** El primer encargo es el más difícil de los pendientes técnicos
de la Fase 2: datos sensibles, permisos que se revocan y dos celulares simulados contra un
PowerSync real. Conviene que lo haga el modelo más capaz.

Hola, Stefano. La Fase 2 ya está integrada en `main` (commit `4fb7761` o posterior) y toda su CI
está en verde. Conoces bien el repo porque los Lotes C y D son tuyos. Este encargo cierra dos
pendientes que necesitan Docker, que en la Mac de integración no hay.

En paralelo trabajan otras ramas; la sección "Para no pisarse" dice qué no tocar.

## Antes de empezar

Lee, en este orden:

1. `reglas-de-trabajo.md` y los `AGENTS.md` aplicables.
2. `docs/fase-2/integracion.md`, sobre todo "Caso asignado en el celular", "Ubicación exacta" y
   las decisiones entre lotes. No reabras esas decisiones; si no estás de acuerdo, dilo en la
   entrega.
3. `docs/fase-2/lote-a-pedidos-offline-y-modo-operativo/README.md` (parte 2) y
   `docs/fase-2/evidencias/streams-por-asignacion.md`.
4. `openspec/changes/fase-2-lote-a-pedidos-offline-y-modo-operativo/tasks.md` (tareas 2.1 a 2.4) y
   `specs/sincronizacion/datos-sensibles-bajo-demanda/spec.md`.
5. `infra/README.md`, `infra/docker-compose.yml` e `infra/powersync/` (`service.yaml` y
   `sync-config.yaml`).

## Reglas de la entrega

1. Dos ramas nuevas desde `main` actualizado:

   ```bash
   git fetch origin
   git switch -c f2-lote-a/parte-2-powersync-en-vivo origin/main
   git switch -c f2-ci/referencias-linux origin/main
   ```

2. Commit y push **solo de tu rama** (`git push -u origin <rama>`). Nada de merge, rebase,
   cherry-pick ni PR. No toques `main` ni borres ramas.
3. En responsables, autores o revisores solo van usuarios de GitHub del equipo: `JDiazD33`,
   `stefanods29`, `Defartion`, `KQuirosA`. Nunca el nombre de un agente, modelo o herramienta.
   Ninguna mención de herramientas de IA en commits, código ni documentos, y ninguna línea
   `Co-Authored-By`.
4. Marca una tarea `[x]` solo con evidencia: la prueba pasando, el comando y su resultado.
5. Solo datos ficticios. Las evidencias nunca llevan ubicaciones, descripciones, teléfonos ni
   tokens, aunque sean de prueba. No subas el `.env` ni claves.
6. Si una prueba revela un error de producción, arréglalo en el mismo commit que la prueba que lo
   demuestra y explícalo en la entrega. Si el arreglo cambia una decisión de
   `docs/fase-2/integracion.md`, primero pregunta.

## Para no pisarse

Otras ramas en curso:

| Rama | Qué cambia |
|---|---|
| `f2-lote-b/parte-3-4-pruebas` | Pruebas de escalamiento y recursos del backend |
| `f2-lote-d/parte-3-frescura` | `emergency.dart`, `operational_emergency_repository.dart` y `CriticalResourceCard` |
| `f2-lote-d/parte-1-2-pruebas-pantallas` | Pruebas de pantallas del tablero |
| `f2-lote-c/parte-1-2-pruebas-pantallas` | Pruebas de la consola y OpenTofu |

No modifiques esos archivos. Tus cambios van en `infra/`, en `backend/test/` (pruebas nuevas), en
`app/test/` (pruebas nuevas) y en la documentación de evidencias.

## Encargo 1 · PowerSync en vivo con dos cuentas

Rama `f2-lote-a/parte-2-powersync-en-vivo`. Cierra A **2.1**, **2.2**, **2.3** y **2.4** si la
evidencia alcanza. Hasta ahora solo se probaron con el evaluador de Sync Streams y con dobles.

### Qué hay

- **Streams:** `infra/powersync/sync-config.yaml`:
  - `caso_asignado` (alcance `resumen`)
  - `caso_ubicacion_exacta` (alcance `exacta`, solo en camino)
  - `mi_pedido`
  - `agregados_de_mi_zona` y `recursos_criticos_de_mi_zona`
- **Backend:**
  - `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion` concede el permiso auditado.
  - Las copias mínimas `emergencias.historial_para_autor` y `emergencias.ubicaciones_en_camino` las
    mantienen disparadores de la base.
  - Al terminar la asignación se revoca el permiso (`autorizaciones_stream.revocada_en`).
  - Migración: `backend/src/modules/emergencias/infrastructure/migrations/202611160100_emergencias_streams_operativos.ts`.
  - Credenciales de PowerSync: `GET /v1/sync/credenciales`; el token lleva `sub`, `zona`, `roles` y
    `sid`.
- **App:**
  - `app/lib/features/emergencias/assigned_case_cache.dart` y
    `data/http_assigned_case_access.dart`: abrir, purgar y revocar.
  - `own_help_request_repository.dart` (`mi_pedido`) y `powersync_emergency_board.dart`.
- **Prueba del flujo por la API:** `backend/test/integration/emergencies.int-spec.ts`. Úsala de
  modelo para crear los datos: habilitaciones, turnos, evento y pedido.

### Qué hacer

1. Levanta PostgreSQL, PowerSync y la API con `docker compose -f infra/docker-compose.yml up -d
   --wait`, `npm run db:migrate`, `npm run db:seed` y `npm run start:dev`. Si `journeyapps/powersync-service:latest` no
   arranca con la configuración, fija una versión concreta y explícalo. Comprueba que el rol
   `powersync_rol` existe y lee las tablas publicadas: la migración solo le da permisos si existe.
2. Escribe una prueba de punta a punta, repetible y documentada, con **dos clientes PowerSync**
   como dos celulares: brigadista 1 y brigadista 2, o la misma cuenta con dos sesiones (`sid`
   distintos). Puede ser:
   - un script del backend con `@powersync/node` o el cliente HTTP de sincronización; o
   - pruebas de Flutter en VM con `powersync` contra el servicio local.

   Elige lo más estable y explica por qué. Debe comprobar:
   - **2.1:**
     - sin asignación activa, cero filas de `caso_asignado`;
     - antes de *en camino*, cero filas de `caso_ubicacion_exacta`, aunque haya permiso de resumen;
     - en *en camino*, con permiso `exacta`, llega la ubicación;
     - al salir de *en camino*, la fila desaparece en la siguiente sincronización.
   - **2.2:**
     - cada apertura queda en `emergencias.auditoria` con actor, fecha y caso, sin contenido;
     - una suscripción directa sin permiso de esa asignación, sesión y alcance recibe cero filas,
       aunque la asignación exista;
     - otra sesión de la misma cuenta tampoco hereda el permiso.
   - **2.3:**
     - al reasignar el caso de la brigadista 1 a la 2, el celular 1 pierde el resumen y la
       ubicación en la siguiente sincronización y el 2 los recibe después de abrir;
     - al cerrar el caso ninguno conserva filas;
     - verifica también la purga local de `AssignedCaseCache`: memoria, archivo y clave.
   - **Privacidad:**
     - ningún stream automático (`auto_subscribe: true`) entrega datos sensibles;
     - `detalles_pedidos` sigue fuera de la publicación;
     - el autor no recibe filas de `ubicaciones_casos`.
3. Agrega un job de CI solo si el servicio es estable en GitHub Actions (por ejemplo, en
   `backend.yml` con servicios de Docker). Si no lo es, deja el comando documentado y explica por
   qué no entra a la CI.
4. Registra la evidencia en `docs/fase-2/evidencias/powersync-en-vivo.md`:
   - versión del servicio, commit y comandos;
   - cada caso con su resultado;
   - lo que no cubre: celulares reales y señal débil son la prueba de campo (A 5.2).

### Verificación del Encargo 1

```bash
cd backend && npm run verify && npm run test:integration
cd ../app && tool/verify.sh
openspec validate --all --strict
```

más tu comando de PowerSync en vivo. Marca 2.1, 2.2 y 2.3 con su evidencia, y 2.4 solo si
también pasan `npm run verify`, las pruebas de PowerSync y `tool/verify.sh`. Actualiza la nota
"Integración en `main`" de la parte 2 en el `tasks.md` de A y la fila de la parte 2 en la tabla
de estado del Lote A. El responsable sigue siendo `JDiazD33`.

## Encargo 2 · Referencias visuales del modo emergencia también en Linux

Rama `f2-ci/referencias-linux`. No cierra una tarea de OpenSpec: hace que la CI compare las
imágenes de la prueba de accesibilidad de D.

### Situación

`app/test/features/emergencias/emergency_accessibility_test.dart` genera seis imágenes al 200 %
en `app/test/features/emergencias/goldens/`. Se generaron en macOS. En la CI (Ubuntu) el suavizado
de la fuente de prueba difiere más del 1 % aceptado y las seis fallaron. Por eso hoy la comparación
se salta fuera de macOS (`_goldenSkip`). Las otras 27 comprobaciones sí corren en la CI.

### Qué hacer

1. Genera las referencias en el mismo entorno que la CI: Ubuntu, Flutter `3.47.9` (versión de
   `.github/workflows/app.yml`). Puedes usar un contenedor Docker con Flutter 3.47.9 o un
   `workflow_dispatch` que suba las imágenes como artefacto.
2. Guarda una carpeta por sistema (`goldens/linux/` y `goldens/macos/`, moviendo ahí las
   actuales) y elige la carpeta según `Platform.operatingSystem`. Quita el salto de Linux. En
   cualquier otro sistema se salta con su motivo.
3. Comprueba que la CI de la app compara las seis en Linux y queda en verde. Si la fuente sigue
   variando entre corridas de Ubuntu, explica cuánto, en lugar de subir la tolerancia sin medir.
4. Actualiza `docs/fase-2/evidencias/accesibilidad-modo-emergencia.md`: dónde se generan y cómo
   regenerarlas, por ejemplo `flutter test --update-goldens` dentro del contenedor.

### Verificación del Encargo 2

`tool/verify.sh` en macOS (compara `goldens/macos/`) y la CI de tu rama en verde con la
comparación de Linux. Como la CI solo corre en `main` y en PR, y no abrimos PR, pega en la entrega
la salida del contenedor o del `workflow_dispatch`.

## Entrega

Para cada rama, devuelve:

- Nombre de la rama y SHA final (ya subida con `git push -u origin <rama>`).
- Archivos nuevos o cambiados y por qué. Si arreglaste un error de producción, cuál y qué prueba
  lo demuestra.
- Comandos corridos con su resultado y la versión de PowerSync usada.
- Tareas marcadas y las que quedan abiertas, con el motivo.
- Dudas o desacuerdos con `docs/fase-2/integracion.md`, sin cambiarlo por tu cuenta.
