# Spec Delta

## Purpose

Permitir que un vecino guarde su pedido sin señal y consulte después su estado real y su historial privado.

## ADDED Requirements

### Requirement: Guardado local antes de confirmar la acción

El celular SHALL guardar el pedido en la cola cifrada de la cuenta antes de mostrarlo como guardado. Cada pedido SHALL tener un UUIDv7 y una clave de idempotencia generados al crearlo y conservados en todos los reintentos.

#### Scenario: Crear un pedido y reiniciar sin señal

- **WHEN** el vecino crea un pedido en modo avión y reinicia la app
- **THEN** puede consultar el mismo pedido con su estado local, su identificador y su clave originales
- **AND** la app dice «Tu pedido todavía no fue enviado. Nadie lo ha recibido.» y mantiene disponibles las alternativas de la sección 7.4

### Requirement: Confirmación verificable del envío

La app SHALL mostrar el pedido como enviado solo cuando el servidor confirme su recepción. Los reintentos con la misma clave MUST NOT crear otro pedido. Si hay un rechazo definitivo, la app SHALL mostrar el motivo y una alternativa, y permitir que la cola continúe.

#### Scenario: Se pierde el acuse al recuperar la señal

- **WHEN** el servidor guarda el pedido y se corta la conexión antes de que el celular reciba el acuse
- **THEN** la app reintenta con el mismo identificador y la misma clave, y muestra el envío una sola vez al confirmarlo

#### Scenario: Zona sin cobertura operativa

- **WHEN** el servidor rechaza definitivamente el pedido por falta de cobertura
- **THEN** el vecino ve el rechazo y las alternativas oficiales
- **AND** el pedido no queda como enviado ni impide procesar los siguientes

### Requirement: Estado e historial del pedido propio

El vecino SHALL recibir el estado y el historial de sus propios pedidos. La app SHALL indicar la última actualización cuando se consulta sin señal y aplicar las transiciones confirmadas por el servidor al reconectar.

#### Scenario: Derivación o cierre mientras el vecino está sin señal

- **WHEN** el pedido fue derivado o cerrado sin atender mientras el celular no tenía conexión y el vecino vuelve a sincronizar
- **THEN** la app muestra el estado confirmado, la hora, el motivo y el siguiente paso
- **AND** un dato local anterior no reemplaza la transición confirmada

#### Scenario: Consulta de un pedido ajeno

- **WHEN** otro vecino solicita la sincronización con el identificador de un pedido que no creó
- **THEN** no recibe el pedido ni las filas de su historial
