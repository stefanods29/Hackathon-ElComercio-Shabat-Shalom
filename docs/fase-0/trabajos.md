# Contratos de trabajos · Lote B, Parte 4

Esta parte no agrega rutas HTTP ni cambia `contracts/openapi.yaml`. El contrato que entrega es
el de los trabajos internos. El Lote C consume la interfaz pública de `notificaciones/index.ts`.

| Nombre | Carga JSON | Prioridad | Reintentos | Productor | Consumidor |
|---|---|---|---|---|---|
| `solidaridad.publicacion_creada` | `{ eventoId, modulo, agregadoId, carga, ocurridoEn }` | normal | 5 | Relay del outbox | Manejadores que se registren; quedan pendientes hasta entonces |
| `solidaridad.favor_tomado` | `{ eventoId, modulo, agregadoId, carga, ocurridoEn }` | normal | 5 | Relay del outbox | Lote C: genera `notificaciones.enviar_aviso` |
| `notificaciones.enviar_aviso` | `SendNotificationJob` (abajo) | normal; crítica para emergencias | 5 | Lote C | Lote C: envío idempotente |
| `plataforma.limpieza_diaria` | `{}` | baja | 5 | Programación diaria, 04:00 `America/Lima` | Worker de limpieza |

`ocurridoEn` es ISO 8601. El relay conserva el nombre del evento y usa su id como clave de
deduplicación. Los eventos del módulo `emergencias` tienen prioridad crítica.

## Avisos para el Lote C

```ts
interface SendNotificationJob {
  readonly avisoId: string;
  readonly destino:
    | { readonly tipo: 'usuario'; readonly usuarioId: string }
    | { readonly tipo: 'zona'; readonly zonaId: string };
  readonly plantilla: 'favor_tomado' | 'aviso_de_zona';
  readonly datos: Readonly<Record<string, string>>;
}
```

`datos` contiene solo identificadores. Nunca nombres, teléfonos, ubicaciones ni datos de salud.
El manejador de C debe deduplicar por `avisoId`: la entrega es al menos una vez y un reintento no
debe producir un segundo aviso. El envío real y su verificación pertenecen al Lote C.

## Entrega

Se comienza por la Parte 4 por indicación del responsable del Lote B. Es independiente de las
Partes 1–3: usa el outbox y el puerto `JobQueue` que ya existen en los cimientos.

## Ejecución y garantías

- Instalar con `cd backend && npm ci`. `JOB_QUEUE_DRIVER=pgboss` es el valor por defecto;
  `memory` solo se permite en pruebas.
- API: `npm run start:dev`. En otra terminal: `npm run start:workers:dev`.
  En producción, después de compilar: `npm run start:prod` y `npm run start:workers`.
- pg-boss 12.38.1 crea y migra su esquema `colas` al iniciar. El usuario de conexión necesita
  permisos para crear ese esquema y administrar sus objetos; no se agrega ninguna tabla a
  la publicación de PowerSync.
- La API solo produce trabajos, con supervisión y cron deshabilitados. Los workers registran
  manejadores en `JobHandlerRegistry` durante `onModuleInit`; al terminar el arranque se
  inician todos. El Lote C registra sus manejadores en su módulo, que ya importa el proceso
  de workers. Una cola sin manejador conserva el trabajo pendiente.
- El relay toma hasta 100 eventos con `FOR UPDATE SKIP LOCKED` cada segundo sin solapar lotes.
  `fromKysely(tx)` publica en la misma transacción que actualiza `publicado_en`.
  Una caída antes del commit revierte ambos cambios. Un savepoint por evento permite revertir
  solo el envío fallido, incrementar `intentos` y continuar con el resto del lote.
- Cinco reintentos significa seis ejecuciones como máximo, contando la inicial
  (`retryLimit=5`). La espera crece exponencialmente con variación aleatoria.
  Al agotarse, `<nombre>.fallidos` retiene la carga y el error para diagnóstico.
- Prioridades: crítica 20, normal 10 y baja 0. Se ordenan dentro de cada cola; las distintas
  colas tienen consumidores independientes. No se promete un orden global entre colas.
- Política `exclusive` por `singletonKey`: deduplica mientras hay un trabajo pendiente,
  en reintento o activo. Sin clave se genera una nueva para conservar todos los envíos.
  Tras completarse puede volver a entregarse: el consumidor debe deduplicar su efecto con el
  identificador de negocio, por ejemplo `avisoId` en el Lote C.
- La limpieza diaria borra claves de idempotencia vencidas y solo eventos publicados hace
  más de 30 días; conserva eventos pendientes y publicados recientes.
- Al cerrar el proceso se espera al lote del relay y a los manejadores activos antes de
  cerrar la base de datos.

## Registrar un manejador (Lote C)

Inyecta `JobHandlerRegistry` desde `shared/queues/job-handler.registry.js` en un proveedor de
`NotificationsModule`. En `onModuleInit`, llama a
`registry.register<SendNotificationJob>(SEND_NOTIFICATION_JOB, handler)`.
Los módulos no arrancan consumidores directamente en la API: el proceso de workers llama a
`startAll` después de que todos registraron sus manejadores. Un registro duplicado o tardío
falla de forma explícita.

## Diagnóstico desde PostgreSQL

```sql
-- Estado y cantidad de trabajos por cola.
SELECT name, state, count(*) FROM colas.job GROUP BY name, state ORDER BY name, state;

-- Fallidos: carga, error original y momento del fallo (sin copiar datos privados a informes).
SELECT name, id, source_name, source_output, created_on
FROM colas.job WHERE name LIKE '%.fallidos' ORDER BY created_on DESC;

-- Eventos por publicar y número de intentos.
SELECT id, modulo, tipo, intentos, ocurrido_en FROM compartido.outbox
WHERE publicado_en IS NULL ORDER BY ocurrido_en, id;
```

Referencias de la dependencia: [transacciones](https://pgboss.io/api/adapters),
[colas y políticas](https://pgboss.io/api/queues) y
[opciones de trabajos](https://pgboss.io/api/jobs).
