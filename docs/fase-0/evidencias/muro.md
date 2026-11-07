# Muro completo · Lote B, Parte 5

Fecha: 2026-11-07. Rama: `lote-b/parte-5-muro`. Base:
`41b7f6ae0d8bb796f695cd3d0f14a1629421e4fc` (Parte 2 con OTP y sesiones corregidos).
Contrato previo a la implementación: `83fa08f`. La rama se conserva pendiente de revisión,
sin merge, rebase, cherry-pick ni PR, por indicación del equipo.

## Resultado

- `GET /v1/publicaciones`: exige acceso y zona; consulta solo publicaciones abiertas de esa
  zona, no eliminadas, con ubicación y sin vencer. Radio 100–5000 m (2000 por defecto),
  páginas de 1–50 elementos (20 por defecto), orden por distancia/id.
- La consulta usa `ST_DWithin` sobre `geography` y el índice GiST existente. La posición de
  búsqueda no se persiste; la ubicación publicada ya está aproximada a unos 100 m y
  `distanciaMetros` se redondea a múltiplos de 50 m.
- El cursor sigue el formato `base64url(JSON { d, id })`. `d` también se redondea a 50 m,
  para que decodificarlo no revele la distancia precisa. El servidor reconstruye la clave
  de orden usando el id de anclaje, sin perder filas que comparten distancia redondeada.
- `POST /v1/publicaciones/{id}/cancelar`: solo el autor, publicación abierta, misma zona y
  versión vigente. Pasa a `cancelada` y emite `solidaridad.publicacion_cancelada`.
- `POST /v1/publicaciones/{id}/resolver`: autor o tomador, favor en curso, misma zona y
  versión vigente. Pasa a `resuelta` y emite `solidaridad.favor_resuelto`.
- Ambas escrituras exigen `Idempotency-Key`. La repetición por dominio tampoco incrementa
  versión ni duplica eventos; una carrera perdida se relee para explicar el conflicto.
  Estado y outbox se guardan o revierten juntos.
- `MAX_POSTS_PER_DAY` (entero positivo, 10 por defecto) cuenta publicaciones nuevas por
  autor en las últimas 24 horas, incluidas canceladas/eliminadas. El id existente se comprueba
  primero. Un bloqueo transaccional por autor impide superar el límite con solicitudes paralelas.
  El 429 `limite_diario_alcanzado` incluye `Retry-After` y `reintentarEnSegundos`.

No se agregan dependencias, migraciones, tablas ni streams. La nueva variable está en
`backend/.env.example` y en la validación de configuración. El grafo incorpora la dependencia
de Solidaridad hacia configuración compartida.

## Verificación local

Node 26.13.0, PostgreSQL 18.6 y PostGIS 3.7. Cada corrida de integración crea, migra,
siembra y elimina una base temporal. Los usuarios del límite se crean por OTP falso,
eligen zona, reciben nivel 1 mediante SQL de prueba y renuevan sus claims.
No se usan datos reales ni se envían SMS.

| Comprobación | Resultado |
|---|---|
| `npm run verify` | 112 unitarias; tipos, lint sin advertencias, formato, fronteras, Sync Streams y build correctos |
| `npm run test:integration` | 81 pruebas en 9 archivos, con PostgreSQL/PostGIS reales |
| `npm run graph` | Ejecutado y grafo actualizado |
| Redocly 2.76.0 | Contrato válido; 3 advertencias preexistentes sobre respuestas 4xx en salud, JWKS y zonas |
| OpenSpec estricto | 10 aprobados, 0 fallidos |
| `git diff --check` | Correcto |

Las 46 unitarias nuevas incluyen la matriz de cancelación/resolución por estado y actor,
versiones viejas, eventos, carreras simuladas, repetición, límite móvil y validación de cursor.
Las 22 integraciones nuevas cubren:

- Publicaciones a unos 500 m, 1,5 km y 3 km del punto piloto; radio 2 km devuelve las dos
  primeras en orden. `limite=1` recorre ambas páginas.
- Empates reales por UUID y distancias distintas en un mismo múltiplo de 50 m, sin omisiones.
  El cursor conserva su ancla tras cancelación o borrado lógico; no filtra distancia precisa.
- Exclusión de otros estados, vencidas, eliminadas, sin ubicación y otras zonas; consulta vacía,
  coordenadas/rangos inválidos, cursores inválidos y falta de acceso/zona.
- Autoría/participación, zona, versiones viejas, repetición HTTP y por dominio, eventos únicos,
  cancelaciones paralelas, resolución simultánea por autor/tomador y carrera tomar/cancelar.
- Con límite 3, la cuarta alta da 429 con espera coherente. Diez altas paralelas producen
  exactamente 3 publicaciones y 7 respuestas 429. Seis reintentos paralelos del mismo id
  producen una sola alta. Cancelar/eliminar no libera cupo; vencer la ventana sí.
- Un fallo del outbox revierte el cambio y permite reintentar la misma clave.

La prueba HTTP de concurrencia escucha una sola vez en un puerto efímero local para evitar
acumular callbacks de arranque de Supertest. Se mantienen todas las regresiones de OTP y sesiones.

## CI remoto

Ejecuciones manuales sobre `lote-b/parte-5-muro`, commit de implementación
`5597e15c141bf50a1a7cf56b1ead794bf76ada08`, completadas en verde:

- [Backend: tipos, lint, formato, fronteras, Sync Streams, pruebas, build e integración](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42384660262).
  La integración remota usa PostgreSQL 18 + PostGIS 3.6.
- [Especificaciones: OpenSpec estricto y contrato OpenAPI](https://github.com/stefanods29/Hackathon-ElComercio-Shabat-Shalom/actions/runs/42384662686).

Las tareas 5.1–5.4 están verificadas. El commit posterior solo registra esta evidencia y
el estado de entrega; no cambia código. La rama queda pendiente de revisión, sin PR ni integración.

## Puntos de contacto y límites

Para el Lote A: consultar cercanía al tener conexión y conservar el mismo punto/radio al
paginar. La lectura no fija una instantánea; si se reinicia la búsqueda o desaparece físicamente
el ancla, descartar el cursor y empezar otra vez. Las escrituras offline mantienen su misma
clave de idempotencia; un 409 explica qué cambió y un 429 permite reintentar tras la espera.

Para las Partes 3 y 4: se conservan sus ramas. Esta parte usa el contrato existente de Actor,
el control de nivel al publicar y el puerto de outbox; no incorpora sus guards ni workers.
Los eventos nuevos llevan solo ids, sin ubicaciones ni textos personales. Las casillas de
esas partes en esta rama siguen pendientes porque sus commits no forman parte de su base.
La integración entre ramas queda para la revisión y autorización del equipo.

La prueba manual real de Twilio (1.4) sigue pendiente. La prueba de carga k6 corresponde a
la Parte 6 y no se declara verificada aquí.

Referencias técnicas: [ST_DWithin](https://postgis.net/docs/ST_DWithin.html) para distancia en
metros e índice espacial; [ST_Project](https://postgis.net/docs/ST_Project.html) para las
posiciones de prueba, con tipos explícitos que evitan ambigüedades entre sus sobrecargas.
