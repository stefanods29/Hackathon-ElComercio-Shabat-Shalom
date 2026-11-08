## ADDED Requirements

### Requirement: Inicio en modo emergencia
Con un evento activo en la zona o el modo emergencia encendido, la app SHALL abrir el tablero de
emergencia. Sin cobertura operativa verificada SHALL mostrar el directorio de emergencia y los
números oficiales, y explicar que todavía no hay coordinación vecinal.

#### Scenario: La zona no tiene cobertura
- **WHEN** el vecino abre el tablero en una zona sin coordinación confirmada por la API
- **THEN** ve las alternativas oficiales y el botón de enviar un pedido no está disponible

### Requirement: Pedido propio con su estado real
El pedido SHALL crearse en tres toques y guardarse en el celular con su identificador y su clave de
idempotencia. Mientras no tenga el acuse del servidor, la app SHALL decir que todavía no fue enviado
y que nadie lo ha recibido. Las alternativas oficiales MUST seguir visibles en todos los estados.

#### Scenario: Pedido sin señal
- **WHEN** el vecino envía un pedido sin conexión
- **THEN** el pedido queda en la cola cifrada de su cuenta y se muestra como no enviado

#### Scenario: Llega el acuse
- **WHEN** el stream del autor confirma el pedido
- **THEN** la app muestra la hora de envío y los estados siguientes sin datos de quien ayuda

### Requirement: Recursos con antigüedad y fuente
La lista de recursos SHALL mostrar cuándo se reportó cada uno, marcarlo como posiblemente
desactualizado según su tipo y mostrar la fuente solo cuando la verificó una persona habilitada.
Un reporte vecinal MUST NOT llevar texto libre a la API.

#### Scenario: Reporte de un recurso
- **WHEN** el vecino reporta agua disponible en su cuenta real
- **THEN** la app envía el tipo, la cantidad y el punto aproximado, y nada más

### Requirement: Contactos de emergencia propios
Los contactos de emergencia SHALL guardarse cifrados por cuenta y MUST borrarse al cerrar sesión o
al cambiar de cuenta. Preparar un SMS MUST NOT enviarlo.

#### Scenario: Cambio de cuenta
- **WHEN** otra cuenta inicia sesión en el mismo celular
- **THEN** no ve los contactos de la cuenta anterior
