# Spec Delta

## Purpose

Guardar en el celular cada acción hecha sin conexión y entregarla al servidor exactamente una vez cuando haya red, mostrando siempre su estado real.

## ADDED Requirements

### Requirement: La cola sobrevive al celular
Toda acción SHALL guardarse en la base local antes de mostrarse como hecha y MUST sobrevivir a modo avión, cierre forzado de la app, reinicio del teléfono y batería baja.

#### Scenario: 500 operaciones en condiciones difíciles
- **WHEN** se ejecutan 500 acciones alternando modo avión, señal débil, cierre forzado y reinicio en un Android de gama baja y en un iPhone
- **THEN** el servidor recibe las 500, sin pérdidas y sin duplicados

### Requirement: Cada acción llega una sola vez
El envío de cada acción SHALL incluir su `Idempotency-Key` original en todos los reintentos, de modo que repetir un envío no cree efectos duplicados en el servidor.

#### Scenario: Se corta la señal justo después de enviar
- **WHEN** el servidor guardó la acción pero el celular no recibió la respuesta y reintenta
- **THEN** el servidor responde con la respuesta guardada y la acción queda "Enviado" una sola vez

### Requirement: Un rechazo no bloquea la cola
Ante un rechazo definitivo la app SHALL marcar la acción "No se pudo completar", deshacer su cambio optimista, guardarla en "acciones por revisar" con el motivo del servidor y continuar con las siguientes acciones.

#### Scenario: Dos vecinos toman el mismo favor sin conexión
- **WHEN** el segundo vecino recupera la señal y su acción recibe 409 `favor_no_disponible`
- **THEN** su muro vuelve a mostrar el favor como tomado por otro, ve el motivo y una alternativa
- **AND** sus otras acciones pendientes se envían normalmente

### Requirement: Reintentos sin prometer de más
La cola SHALL reintentar al abrir la app, al volver a ella y al recuperar la conexión, con espera exponencial y variación aleatoria; en segundo plano solo de forma oportunista, sin que la UI prometa envíos inmediatos.

#### Scenario: Vuelve la señal con la app en segundo plano
- **WHEN** hay acciones pendientes y la app está en segundo plano
- **THEN** la UI sigue mostrando "Guardado en tu celular" hasta que el envío se confirme

### Requirement: Credenciales vigentes
El conector SHALL obtener y renovar el token de sincronización con `GET /v1/sync/credenciales` antes de que venza, sin intervención del vecino.

#### Scenario: Token a punto de vencer
- **WHEN** faltan menos de dos minutos para que venza el token
- **THEN** el conector pide uno nuevo y la sincronización continúa sin cortes
