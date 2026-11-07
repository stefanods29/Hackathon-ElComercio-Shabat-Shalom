# Conflicto: dos vecinos toman el mismo favor

- Fecha: 7 de noviembre de 2026, al cerrar la Fase 0.
- Criterio: «Los rechazos y conflictos se entienden» (A · 5.3 + D · 3.3).
- Alcance aprobado por el usuario: si dos vecinos toman el mismo favor, se queda con él **el
  primero que llega al servidor**. El segundo recibe el motivo y una alternativa. La prueba con dos
  celulares sin conexión pasa al piloto de la Fase 1 (Lote A, parte 5).

## Regla

`POST /v1/publicaciones/{id}/tomar` exige la versión que vio el vecino (`versionVista`). Gana la
primera toma que llega. La segunda recibe `409 favor_no_disponible` («Otro vecino ya tomó este favor
o ya no está disponible.») junto con el estado actual del favor. Si el ganador reintenta con la misma
`Idempotency-Key`, porque su celular no recibió la respuesta, obtiene la misma respuesta y no un
error.

En la app, la cola de subida clasifica ese 409 como rechazo definitivo y revierte el cambio
optimista. Además, guarda el envío en «Acciones por revisar» con el motivo del servidor, aunque la
publicación ya no aparezca en el muro.

## Pruebas automatizadas

| Prueba | Qué demuestra |
| --- | --- |
| `backend/test/integration/api.int-spec.ts` · «dos vecinos toman el mismo favor: el primero gana, el segundo entiende por qué» | Beto toma el favor (200, versión 2). Carla recibe 409 `favor_no_disponible` con `estadoActual`. El reintento de Beto con su misma clave vuelve a dar 200. |
| `backend/test/integration/wall.int-spec.ts` · «tomar y cancelar en paralelo dejan un único ganador y el perdedor recibe 409» | Con operaciones concurrentes en PostgreSQL hay una sola transición y un solo evento. |
| `backend/src/modules/solidaridad/domain/post-lifecycle.spec.ts` | Reglas de estado y versión del favor en el dominio. |
| `app/test/core/network/classify_response_test.dart` | Un 409 con Problem Details es un rechazo definitivo con su motivo. |
| `app/test/features/solidaridad/integrated_screens_test.dart` · «el rechazo sigue visible con motivo y alternativa aunque el post desaparezca» | La pantalla del Lote D muestra el motivo y la alternativa después del rechazo. |

Las pruebas corren en la CI de backend y de la app (`npm run test:integration` y `flutter test`).

## Pendiente para el piloto

Repetir el caso con dos celulares sin conexión que se reconectan en distinto orden, y registrar
qué ve cada vecino. Esta prueba no bloquea el cierre de la Fase 0.
