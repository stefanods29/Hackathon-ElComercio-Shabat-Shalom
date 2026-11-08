# Avisos · Lote C

`api/` valida el contrato y la sesión. `application/` registra los manejadores y depende de
puertos. `domain/` define texto genérico. `infrastructure/` contiene PostgreSQL y Firebase.
Las tablas privadas nunca se publican mediante PowerSync.

## Dispositivos

`POST /v1/dispositivos` y `POST /v1/dispositivos/baja` requieren JWT e `Idempotency-Key`.
El alta reasigna y reactiva una instalación existente; la baja solo afecta a su dueño actual.
La respuesta no expone el identificador de Firebase. `registradoEn` conserva el alta original.
Se indexa SHA-256 del token: PostgreSQL no admite indexar directamente todos los tokens de
4096 bytes permitidos por el contrato. Se conserva y comprueba también el valor original.

## Entrega y reintentos

`solidaridad.favor_tomado` recibe el sobre del relay de B: `eventoId`, `agregadoId`,
`carga.autorId`. Genera UUIDv5 estable y encola `notificaciones.enviar_aviso`.
El contrato exportado desde `index.ts` coincide con el de B4. `JobHandlerRegistry` es compatible
con B4; al integrarlo debe quedar una sola clase compartida, y el worker llama `startAll(queue)`.
Mientras B4 no esté integrado, las pruebas arrancan el registro y usan `InMemoryJobQueue.drain()`.
La cola actual no procesa trabajos automáticamente ni persiste al reiniciar.

Cada aviso congela sus destinatarios al primer intento y comprueba que su contenido no cambie.
Cada entrega se bloquea y confirma por separado. Así, la concurrencia no duplica envíos y un
fallo posterior no repite los dispositivos ya completados. Una instalación reasignada o dada
de baja se omite; un identificador inválido se retira. No se añaden nuevos dispositivos en un
reintento de un aviso antiguo. Los bloqueos sobre dispositivos serializan la entrega con la baja.

Existe una ventana inevitable si Firebase acepta un envío y el proceso termina antes de confirmar
PostgreSQL: el reintento podría repetirlo. FCM no proporciona una clave de idempotencia del envío.
No se promete entrega exactamente una vez ante esa interrupción externa. La llamada de red se
mantiene dentro de la transacción de cada destinatario; debe vigilarse la duración al activar B4.

## Firebase y privacidad

`NOTIFICATION_DRIVER=fake` es el valor local y está prohibido en producción. Para `fcm` se exige
`FIREBASE_SERVICE_ACCOUNT_BASE64` en el entorno privado. Nunca colocar credenciales en Git o logs.
Los errores del SDK se sustituyen por errores genéricos para no registrar identificadores privados.

Flutter Messaging 17 utiliza `register()` / `onRegistered` y Firebase Installation IDs (FID).
El contrato conserva el campo opaco `token`; el adaptador Admin 14.5 envía con `fid`, según la
[documentación actual de Firebase](https://firebase.google.com/docs/cloud-messaging/send/admin-sdk).
No debe confundirse este FID con un token JWT ni usar aquí clientes antiguos basados en tokens FCM.

El aviso personal solo dice «Tienes una actualización» y sus datos contienen tipo e identificador.
Los tópicos `zona-<UUID>` son públicos y no constituyen un control de acceso.
La plantilla de zona actual también es genérica; `datos` rechaza texto y campos adicionales.
La ruta operativa con título/texto del coordinador queda pendiente de B3, tal como exige la guía
del lote. No se habilita una ruta de publicación sin sus permisos. Al integrar esa ruta, el texto
público deberá almacenarse de forma autorizada; no ampliar `datos` con contenido personal.

## Comprobación

`npm run verify` y `DATABASE_URL_ADMIN=... npm run test:integration`.
La integración comprueba autenticación, límite de 4096 bytes, repetición del registro, reasignación,
baja, doble entrega concurrente, fallos parciales, identificadores inválidos y envío a un tópico.

## Avisos urgentes con SMS de respaldo (Fase 2, Lote C)

Emergencias (Lote B de la Fase 2) encola `notificaciones.enviar_aviso_urgente` al asignar o
escalar un caso. El contrato `UrgentNoticeJob` se exporta desde `index.ts`: `avisoId`,
`usuarioId`, `plantilla` (`caso_asignado`, `pedido_por_escalar` o `pedido_escalado`) y
`datos.casoId`, que es solo un identificador.

1. **Reclamo:** el trabajo reclama el aviso en `notificaciones.avisos_urgentes`, una sola vez por
   `avisoId` y con huella del contenido.
2. **Push:** envía por la misma entrega idempotente por dispositivo (`entregas_aviso`), con el texto
   "Tienes una actualización urgente".
3. **Revisión programada:** `notificaciones.revisar_aviso_urgente` corre a los
   `URGENT_ACK_TIMEOUT_SECONDS` segundos. Corre de inmediato si ningún dispositivo recibió el push.
4. **Confirmación:** el destinatario confirma con `POST /v1/avisos-urgentes/{id}/confirmar`, desde
   la app al abrir el aviso o desde la consola. `GET /v1/avisos-urgentes` lista sus avisos sin
   confirmar de las últimas 24 horas.
5. **Decisión de la revisión.** Con `FOR UPDATE` sobre el aviso y sobre el gasto del día:
   - si nadie confirmó, el proveedor está activo, hay teléfono y el gasto del día y del mes,
     sumado el del mensaje, no supera `SMS_DAILY_BUDGET_CENTS` ni `SMS_MONTHLY_BUDGET_CENTS`,
     reserva el costo y envía "Vecinal: tienes una actualización urgente. Abre la app para verla.";
   - si no, cierra el aviso como `sin_respaldo`, con `tope_de_gasto`, `sin_proveedor`,
     `sin_telefono` o `sms_fallido`.
   - Un fallo reintentable devuelve la reserva y deja que pg-boss reintente, con un máximo de 3
     SMS por aviso.

El SMS se envía al menos una vez: si el proceso cae entre el envío y su marca, se puede repetir. El
texto es genérico y el tope acota el costo. El teléfono sale de `identidad` (`ContactDirectory`,
desde su `index.ts`) y nunca se escribe en logs. El adaptador falso solo guarda los dos últimos
dígitos.

**Proveedores de SMS:**
- `SMS_PROVIDER=fake` en desarrollo y pruebas; está prohibido en producción.
- `SMS_PROVIDER=none` deja el respaldo apagado y registra `sin_proveedor`.
- El proveedor real es la decisión abierta 13.3.4.

**Medición:** `GET /v1/operacion/avisos-urgentes/resumen`, para `administrador` y `coordinador`,
devuelve los totales por estado, la latencia de confirmación (p50 y p95), los SMS enviados y el
gasto del día y del mes frente a sus topes (centavos de dólar).

**Aviso público de zona:** `emergencias.evento_activado` (`carga.zonaId`) encola
`notificaciones.enviar_aviso` al tópico `zona-<zonaId>`, con la plantilla
`modo_emergencia_activado` y un UUIDv5 por evento y zona. Un evento repetido produce un solo aviso.
