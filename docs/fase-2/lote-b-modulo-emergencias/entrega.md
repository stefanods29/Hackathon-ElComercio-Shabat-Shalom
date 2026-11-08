# Implementación de Fase 2 B para revisión

Rama: `f2-lote-b/modulo-emergencias`. Base: `origin/f1-lote-b/parte-5-moderacion` (`e316409`).
Se reutiliza la entrega completa de Fase 1 B, todavía en su rama de revisión; no se mezclaron
las ramas independientes de C/D ni se modificó la entrega anterior del Lote C.

**Se desarrolló sin compilar ni ejecutar pruebas**, por indicación del usuario. Tampoco se
ejecutaron migraciones, servicios, simulacros, despliegues ni envíos reales de avisos/SMS.

> **Integración en `main` (8 de noviembre de 2026).** El módulo compila, sus migraciones corren y
> la prueba `backend/test/integration/emergencies.int-spec.ts` recorre el hito H2 por la API. La
> integración agregó la migración `202611160100_emergencias_streams_operativos` (copias mínimas
> para los streams de A y permisos auditados), la ruta
> `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion` y la fecha `verificado_en` de los recursos;
> el aviso público de zona quedó solo en C. Detalle en [la integración](../integracion.md). La CI
> todavía no se vio en verde.

## Partes implementadas

| Parte | Código |
| --- | --- |
| 1 · Eventos | Activación por zona, niveles y modos, cobertura en vivo, alertas detrás de un puerto con deduplicación y circuit breaker |
| 2 · Pedidos | UUID estable, huella, escrituras idempotentes, máquina de estados, versiones, prioridad y acceso privado auditado |
| 3 · Operación | Habilitaciones, grupos verificados, acuerdos de apoyo, turnos sin superposición, asignaciones, aviso previo y escalamiento durable |
| 4 · Recursos | Reportes estructurados, frescura configurable, confirmación independiente, verificación humana y agregados con umbral de tres |
| 5 · Privacidad | Rol curador, requisitos operativos, auditoría por acceso, revocación, exportación/borrado de cuentas y cierre con anonimización por lotes |

Se agregan dos migraciones: rol curador en Identidad y extensión operativa de Emergencias.
Las tablas mínimas de A conservan sus IDs. La descripción y ubicación privada se separan de lo
replicable. Las migraciones no ofrecen una reversión destructiva automática de datos sensibles.

## Secuencia de uso

1. Administración registra la revisión humana del DNI, capacitación y confidencialidad mediante
   `POST /v1/operacion/habilitaciones`; no se reciben imágenes ni números del documento.
   La habilitación es por usuario/zona/rol, con vencimiento. Renovar requiere el ID y
   `versionVista` existentes. La persona debe renovar sus credenciales para recibir el nuevo rol
   y nivel; un JWT anterior no gana privilegios por sí solo.
2. Un coordinador habilitado planifica turnos. Dos coordinadores habilitados y al menos uno
   de turno constituyen la cobertura. Los turnos son de hasta 24 horas y no se superponen.
3. Un coordinador activa un evento. Una fuente configurada también puede activar el modo.
   Esto no habilita pedidos si falta cobertura. `GET /v1/zonas/{zonaId}/cobertura` devuelve
   modo, evento, cantidades de coordinación y `habilitada` para la admisión real.
4. El vecino envía `POST /v1/pedidos-ayuda`, incluso con nivel cero. El servidor comprueba zona,
   ubicación dentro del polígono, evento y cobertura. Registra la asignación inicial y un plazo.
5. El coordinador asignado puede marcar visto, priorizar o asignar un brigadista verificado de
   turno. Otro coordinador de la zona puede tomar el caso con versión. Asignar un brigadista
   conserva `visto`; este confirma después `en_camino`. Solo el vecino confirma `atendido`.
6. Los jobs vuelven a comprobar estado, etapa y plazo antes de actuar. El aviso previo se programa
   un minuto antes. Al vencer, se busca otro coordinador o una zona de apoyo explícitamente
   acordada. Hay hasta tres etapas; se avisa al solicitante para consultar alternativas oficiales.
7. Cerrar un evento pasa a recuperación y retira asignaciones. El worker anonimizador continúa
   por lotes hasta finalizar y conserva un resumen sin identidades, coordenadas ni texto libre.

La versión inicial limita la reasignación a casos enviados/vistos. Un relevo de una brigada ya
en camino requiere diseñar una transición/acreditación de aceptación adicional con los aliados;
no se inventó un regreso de estado que contradiga la sección 7.2.

## Contratos y conexiones con otros lotes

La fuente de verdad es [OpenAPI](../../../contracts/openapi.yaml), con el fragmento
[Emergencias](../../../contracts/emergencias.openapi.json). Toda escritura lleva
`Idempotency-Key`; las modificaciones incluyen `versionVista`. El éxito se responde con 200 y
los errores con Problem Details. Las listas de pedidos, recursos y auditoría usan `cursor`,
`limite`, `elementos` y `siguienteCursor`. La cola puede recorrerse por páginas y ordenarse por
prioridad/antigüedad en el cliente; no está limitada a su primera página.

### Lote A · Sincronización y protección local

- Pedidos propios: `GET /v1/pedidos-ayuda`; detalle con caducidad y auditoría:
  `GET /v1/pedidos-ayuda/{id}`. El detalle devuelve `venceEn` y, para operadores, las asignaciones
  con su vencimiento. Conservar la menor caducidad aplicable, el cifrado y la purga al revocar.
- La columna heredada `detalle` pasa a ser genérica. No ampliar sus streams para incluir texto
  privado: `detalles_pedidos` queda fuera de la publicación. La lectura exacta auditada usa la API.
- Integrar `emergencias.recursos_publicos` y `emergencias.agregados_celda` como streams por zona.
  Están publicadas en PostgreSQL pero esta entrega no modifica el contrato de streams de A.
- Al terminar una asignación no se conserva autorización; el detalle HTTP también verifica
  turno/habilitación/acuerdo. Las filas mínimas de PowerSync conservan el mecanismo de baja.
- Suscribirse con `JobHandlerRegistry.subscribe` a `emergencias.evento_cerrado` para purgar las
  cachés correspondientes, conservando el manejador primario de B. No atribuir
  entrega inmediata a trabajos o sincronización durante suspensión del teléfono.

### Lote C · Consola y avisos

- Conectar sus fábricas HTTP de casos, turnos y celdas. No se copió la consola a esta rama.
  Cola: `/v1/operacion/zonas/{zonaId}/casos`; personas disponibles y tablero de turnos bajo
  ese mismo prefijo. Detalle y acciones: `/v1/pedidos-ayuda/{id}`.
- La cola expone necesidad, prioridad, estado, celda, tiempos y asignaciones, sin descripción ni
  coordenadas. Tomar un caso envía `{ usuarioId: <yo>, rol: "coordinador", versionVista: ... }`
  a `/asignaciones`. El detalle privado solo se abre con una asignación vigente.
- El cuerpo de un turno incluye ID estable, `usuarioId`, `rol`, `inicio` y `fin`. Finalizarlo
  lleva `versionVista`. Un coordinador habilitado puede planificar sin turno activo, evitando
  que el primer turno dependa de sí mismo.
- Celdas: cada fila corresponde a celda/necesidad con `cantidad >= 3`. Agrupar por `limites` e
  identificar categorías suprimidas como no publicables; no tratarlas como cero ni sumarlas.
- `emergencias.evento_activado`: carga `{ zonaId, nivel }`. El registro compartido ya admite
  suscriptores. El aviso compatible de B se desactiva cuando se habilita el flujo urgente de C.
- `notificaciones.enviar_aviso_urgente`: `{ avisoId, usuarioId, plantilla, datos: { casoId } }`.
  Plantillas: `caso_asignado`, `pedido_por_escalar`, `pedido_escalado`. Identidades de aviso
  estables y prioridad crítica. Activar `EMERGENCY_URGENT_NOTICES_ENABLED` solo con el consumidor
  de C integrado; de lo contrario se usa el aviso genérico sin respaldo SMS.
- Nueva plantilla compatible `pedido_actualizado`: solo ID de pedido y, cuando corresponde,
  `alternativas=directorio_emergencia`. Nunca título, necesidad, salud ni posición en el push.
- La consola que necesite curaduría usará `curador` en el enum de roles. La entrega de C debe
  incluirlo en sus guards de curaduría al integrar; aquí se agrega a Identidad y al contrato.

### Lote D · Tablero

- Usar `cobertura.habilitada` y el evento real. Un modo de emergencia activo sin cobertura muestra
  directorio y alternativas, sin formulario de coordinación disponible.
- Mapear estados del contrato, incluyendo `en_camino`; los estados guardados en el celular
  siguen siendo locales. Confirmar atención utiliza la ruta `/estado` con `atendido` y versión.
- Conectar `tipo=pedido_actualizado` del push con el pedido propio/asignado según la sesión;
  si incluye `alternativas=directorio_emergencia`, ofrecer la apertura del directorio.
- Recursos devuelven fecha, umbral, posible desactualización y evidencia. La API pública no
  acepta descripciones libres del reportante; el formulario debe enviar tipo, cantidad y posición.
- La cola offline, los contactos y la oferta voluntaria de "Puedo ayudar" siguen en sus puertos
  de A/D. No se convierten automáticamente en habilitaciones ni acceso a pedidos sensibles.

## Configuración y pendientes de revisión

Las variables están en `.env.example`. El módulo se mantiene apagado con
`EMERGENCIES_ENABLED=false`. Los plazos de ejemplo requieren acuerdo con los aliados y revisión
de privacidad antes de activar admisión. La URL de alertas queda vacía: un proveedor real necesita
un adaptador al feed aprobado; no se inventan APIs oficiales ni se habilita un proveedor SMS.

Antes de integrar, revisar contrato, tipos, fronteras y las dos migraciones; después verificar
transiciones, idempotencia y permisos con PostgreSQL, jobs repetidos, revocación y anonimización.
También hace falta el simulacro, configuración privada, el enlace con A/C/D y la aceptación del
equipo. Nada de eso se presenta como ejecutado en esta entrega.

## Verificación de escalamiento y supresión

Rama `f2-lote-b/parte-3-4-pruebas`, desde `1fb5e12`.

- [Escalamiento](../../../backend/test/integration/emergency-escalation.int-spec.ts).
  El reloj controlado prueba el plazo de las tres prioridades, el aviso previo, los reintentos
  concurrentes y posteriores, el límite de tres etapas y el aviso genérico al autor con el
  directorio de emergencia.
- [Recursos y celdas](../../../backend/test/integration/emergency-resources.int-spec.ts).
  Dos escrituras con la misma versión producen un éxito y un conflicto. La confirmación repetida
  cuenta una vez. La prueba consulta la instantánea en PostgreSQL y en la API antes y después del
  umbral de tres pedidos, de un cierre y del vencimiento. Comprueba también que la respuesta
  omite los totales por celda y que la copia pública de recursos omite el reportante y la huella.
- [Datos de prueba compartidos](../../../backend/test/support/emergency-fixture.ts).
  Las dos suites usan cuentas ficticias con rangos de teléfono separados, habilitan coordinación
  por la API y retiran sus datos de la operación de prueba al terminar.

Desde `backend/`, `npm run verify` pasó con 246 pruebas y compilación. Con
`DATABASE_URL_ADMIN` apuntando al PostgreSQL local con PostGIS, `npm run test:integration` pasó
con 207 pruebas, incluidas las ocho nuevas. Los casos pasaron con la implementación existente.
La comprobación de CI del commit de entrega y la revisión de migraciones de B 5.3 quedan
pendientes para la revisión del equipo.
