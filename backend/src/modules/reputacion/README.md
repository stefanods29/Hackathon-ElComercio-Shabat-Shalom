# Módulo `reputacion`

Es dueño de las reseñas, las referencias a sus fotos, el Visto Bueno y las señales privadas de
antifraude. Consulta dueño, vigencia y zona por `directorio/index.ts`, y edad de la cuenta y
señal de dispositivo por `identidad/index.ts`. Sus adaptadores SQL solo acceden a `reputacion.*`.

| Operación | Resultado |
|---|---|
| `POST /v1/resenas` | 201 `en_revision`; 200 al repetir la clave o un id propio; una por vecino y servicio |
| `POST /v1/servicios/{id}/visto-bueno` | 200, conserva id y nivel inicial al repetir |
| `DELETE /v1/servicios/{id}/visto-bueno` | 204 al quitar o si ya no existe; 200 al repetir la misma clave, por el interceptor común |

Las tres requieren sesión, nivel 1 e `Idempotency-Key`. Reseñar y dar Visto Bueno requieren que
el servicio esté vigente, sea de la misma zona y tenga otro dueño. Retirar borra únicamente la
fila del vecino. Reseñar exige 72 horas de antigüedad y permite cinco reseñas nuevas por ventana
móvil de 24 horas, ajustables por configuración. Las ocultas cuentan para la cuota y un reintento
del mismo id no consume otra plaza.

La reseña, fotos, señal y `reputacion.resena_creada` se guardan en una sola transacción.
`REVIEW_PHOTO_READER` replica la consulta `findOwnedReadyFile(archivoId, propietarioId)` prevista
para `media/index.ts`. Se aceptan hasta tres archivos distintos, propios, listos y de propósito
`resena`. El doble se usa en pruebas; mientras no exista el proveedor C1, una referencia que el
servidor no pueda verificar responde `archivo_no_valido`. No se crean URLs ni variantes públicas.
Los streams acordados muestran fotos solo de reseñas publicadas y fotos no ocultas.

Dar o quitar un Visto Bueno real escribe `reputacion.recalculo_solicitado` en la misma transacción.
El trabajo vuelve a contar reseñas publicadas y Visto Bueno vigentes y emite
`reputacion.agregados_recalculados` con `{ servicioId, totalResenas, sumaCalificaciones,
totalVistosBuenos, vistosBuenosDeLaZona }`. El total general cuenta filas vigentes; el de ranking
cuenta solo nivel al otorgar ≥ 2 y zona capturada igual a la del servicio. Directorio aplica los
hechos y calcula el puntaje. La Parte 5 usará `recalculationRequested()` al cambiar la visibilidad
de una reseña; el trabajo interno no ocupa el manejador de `reputacion.resena_publicada` del Lote C.

`reputacion.senales_resenas` guarda solo el hash del dispositivo registrado en la sesión.
Moderación consulta el número de reseñas de esa señal en las 24 horas anteriores, incluyendo la
actual. A partir de la quinta abre un caso pendiente; la señal no rechaza ni publica reseñas.
Las sesiones sin identificador de dispositivo no generan señal. Ningún hash viaja al outbox,
PowerSync ni las respuestas.

Véase la [entrega de la Parte 3](../../../../docs/fase-1/lote-b-directorio-reputacion-y-moderacion/parte-3.md)
para las migraciones, las pruebas escritas y los pendientes de verificación.
