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
