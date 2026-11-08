# Módulo `emergencias`

**Responsabilidad:** Eventos por zona, pedidos de ayuda con estados y escalamiento, recursos críticos, grupos de apoyo y turnos. Esquema restringido: datos sensibles.

**Entidades principales:** Evento, PedidoAyuda, Asignacion, RecursoCritico, GrupoApoyo, Turno.

**Estado:** implementación de las cinco partes de Fase 2 B, sin compilaciones ni pruebas por
indicación del usuario. La cobertura real, las alianzas y la aceptación siguen pendientes.

## Estructura (igual en todos los módulos)

```text
emergencias/
├── domain/          # entidades y reglas; TypeScript puro, sin NestJS ni Kysely
├── application/     # casos de uso y puertos (interfaces)
├── infrastructure/  # adaptadores: repositorios Kysely, migrations/, clientes externos
├── api/             # controladores REST y esquemas Zod (alineados con contracts/openapi.yaml)
├── emergencies.module.ts
└── index.ts         # interfaz pública: lo único que otros módulos pueden importar
```

Reglas: el módulo es dueño de su esquema de Postgres (`emergencias.*`); nadie más lee ni escribe sus
tablas. Las migraciones van en `infrastructure/migrations/AAAAMMDDHHmm_emergencias_<descripcion>.ts`.

## Flujos

- Un coordinador habilitado activa el modo emergencia de su zona. La activación puede existir
  sin cobertura: en ese caso solo corresponde mostrar las alternativas oficiales.
- Para admitir pedidos deben existir dos coordinadores habilitados, al menos uno de turno y
  un evento activo. No se asigna al solicitante su propio pedido.
- El celular envía un UUID y `Idempotency-Key`. Se conserva la huella de creación; repetir el ID
  con otro contenido no sustituye el pedido. Las modificaciones llevan `versionVista`.
- Un coordinador revisa el pedido y cambia `enviado → visto`. Asignar un brigadista no afirma
  que ya esté en camino: el brigadista debe confirmar `visto → en_camino`.
- Solo el solicitante confirma `en_camino → atendido`. Desde `visto`, el coordinador asignado
  puede derivar o cerrar sin atender, con motivo. No se asignan vecinos sin habilitación.
- El coordinador puede tomar un caso de su zona enviando su propio ID y `rol=coordinador` a
  la ruta de asignaciones. Las reasignaciones de esta versión se limitan a casos enviados/vistos.
- Los plazos generan un aviso previo, trabajos críticos de escalamiento y hasta tres etapas.
  El servidor busca otra persona de turno o una zona de apoyo acordada; nunca declara una
  atención humana por ejecutar un trabajo. Si no hay personas disponibles, mantiene las
  alternativas y vuelve a intentarlo dentro del límite. Un barrido recupera plazos omitidos.

La máquina de estados está en `domain/emergency.ts`; aplicación y puertos no dependen de SQL.
Cada escritura de negocio y sus eventos comparten transacción. Las lecturas de detalle también
son transacciones, para registrar la auditoría antes de responder.

## Privacidad y cierre

`detalles_pedidos` conserva descripción y coordenadas y **no** está publicada en PowerSync.
La columna heredada `pedidos_ayuda.detalle` pasa a contener una etiqueta genérica; la migración
traslada el detalle heredado abierto a la tabla privada. Revisar este cambio con el Lote A antes
de aplicar la migración. Las coordenadas nunca pasan a la tabla replicable.

El detalle solo se devuelve al autor o a una persona asignada con habilitación y turno vigentes.
La ubicación exacta solo se devuelve al autor o al personal asignado en estado `en_camino`.
Una persona de apoyo de otra zona requiere además un acuerdo vigente. Se auditan detalle,
ubicación, exportación propia y las filas consultadas de la cola. Administración consulta la
auditoría; los avisos y logs no reciben la descripción, ubicación ni datos de salud.

Al iniciar el cierre del evento se retiran asignaciones. El worker borra detalles/coordenadas,
retira autor y huella, limpia motivos/identidades del historial y elimina asignaciones por lotes
de 100. Conserva cifras sin texto libre y la auditoría operativa restringida. Un evento sigue
`recuperacion` hasta que no queda ningún lote pendiente. La caducidad también elimina el detalle
de pedidos ya atendidos. La API rechaza lecturas privadas vencidas; la eliminación física depende
de que el worker ejecute su siguiente lote. El participante de privacidad atiende exportación y
borrado de cuentas.

## Recursos y datos públicos

Los reportes contienen tipo, cantidad y celda calculada por el servidor. No aceptan texto libre
de vecinos para publicación. La descripción pública procede del tipo o de una etiqueta revisada.
Actualizar el stock invalida confirmaciones y verificación previas. Confirmar no renueva por sí
solo la fecha del reporte. El autor no puede confirmar su propio reporte y cada vecino cuenta una
sola vez por revisión de stock. La insignia oficial requiere verificación de administración y URL
HTTPS; los demás verificadores necesitan habilitación de coordinador o curador.

`recursos_publicos` excluye al reportante; `agregados_celda` solo contiene grupos de tres o más,
sin totales complementarios. El worker genera instantáneas cada cinco minutos. Una combinación
ausente no equivale a cero. El Lote A define las suscripciones por zona sobre estas tablas.

## Configuración y procesos

Ver todas las variables en `backend/.env.example`. `EMERGENCIES_ENABLED=false` mantiene cerrada
la admisión hasta la revisión del equipo. Los tiempos iniciales son propuestas, no compromisos:
alta 15 minutos, media 2 horas, baja 6 horas, caducidad de datos privados 24 horas.

Los jobs están registrados en el proceso de workers existente (`backend/src/workers/`): revisión
de plazos cada minuto, agregados cada cinco minutos y consulta opcional de alertas cada dos minutos.
No se crean temporizadores de negocio dentro de cada réplica de la API.

El puerto `OfficialAlertSource` permite adaptar una fuente aprobada. El adaptador configurable
espera JSON `{ "alertas": [{ "id": "referencia", "zonaId": "uuid", "nivel": 1,
"emitidaEn": "fecha ISO" }] }`, máximo 64 alertas/256 KiB, HTTPS sin redirecciones, timeout
de cinco segundos, deduplicación por fuente/referencia/zona y circuit breaker tras tres fallos.
Una URL vacía no consulta nada. No se ha conectado ni acreditado un canal IGP/SENAMHI/INDECI.

Hasta integrar los avisos urgentes de C, se usan avisos personales genéricos compatibles con Fase 0.
`EMERGENCY_URGENT_NOTICES_ENABLED=true` requiere su consumidor real; habilita el contrato
`notificaciones.enviar_aviso_urgente`. El SMS de respaldo es responsabilidad de C.

Contrato: `contracts/openapi.yaml` referencia `contracts/emergencias.openapi.json`.
Entrega y conexiones con A/C/D: `docs/fase-2/lote-b-modulo-emergencias/entrega.md`.
