# Módulo `moderacion`

Recibe denuncias, filtra contenido nuevo, mantiene la cola de revisión y aplica decisiones
auditadas. Las tablas de `moderacion` quedan fuera de PowerSync. Los dueños de cada contenido
registran sus adaptadores; ningún módulo consulta tablas de otro para aplicar una decisión.

## Flujo

1. `POST /v1/denuncias` guarda la denuncia y deja el caso pendiente en la misma transacción.
   Un trabajo pasa el contenido y el detalle por texto, imagen y reputación. Una denuncia
   siempre necesita revisión humana.
2. Los trabajos de contenido nuevo ejecutan la misma cadena. Una reseña permanece
   `en_revision` hasta que el filtro la aprueba o un moderador decide. El filtro considera el
   nivel, la suspensión y, para reseñas, si hay cinco o más del mismo dispositivo en 24 horas.
   El módulo recibe el conteo, sin obtener la señal del dispositivo.
3. La decisión humana y su evento se guardan juntos. El consumidor aplica la decisión vigente
   al contenido, aunque se reintente el trabajo o llegue después una decisión más antigua.
   Una revisión humana inicia la medición; una aprobación automática no cuenta como caso.
4. `IS_SUSPENDED` expone la función inyectable `isSuspended(userId, now)`. Los módulos de
   publicación usan el mismo lector dentro de sus transacciones. La sanción dura siete días
   desde la decisión.

La cola expone motivos como códigos y no incluye teléfonos ni detalles libres. La justificación
del moderador queda en la auditoría privada. Para la visibilidad se emite
`{ tipoContenido, contenidoId, motivo }` con un código público.

## Puerto de imágenes

Media puede registrar un `ImageModeration` desde su módulo con
`ImageModerationRegistry.register(inspector)`. El inspector recibe un id de archivo, sin URL ni
bytes en el evento. Sin inspector, cualquier imagen queda `sin_verificar` y pasa a revisión
humana. En denuncias de tipo `foto`, `contenidoId` es el id de `reputacion.resena_fotos`;
el adaptador de Reputación resuelve el `archivo_id` para el filtro.

Los consumidores externos pueden usar `JobHandlerRegistry.subscribe` para observar
`moderacion.contenido_aprobado`, `moderacion.contenido_ocultado` y
`moderacion.contenido_restaurado` después del dueño. Deben ser seguros ante reintentos.
`reputacion.resena_publicada` se emite en la primera publicación de la reseña. La restauración
emite su propio evento, sin duplicar el aviso de primera publicación.
