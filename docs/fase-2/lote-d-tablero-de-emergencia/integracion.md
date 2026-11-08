# Integración del tablero de emergencia

Esta entrega prepara las pantallas y los puertos de integración. No activa coordinación
vecinal ni declara cobertura operativa. La rama incluye las pantallas de Fase 1 sobre
las que se construye el tablero.

## Repositorio operativo

`app/lib/features/emergencias/domain/emergency.dart` define `EmergencyRepository`.
La integración de los Lotes A y B debe proporcionar una fábrica mediante
`operationalEmergencyFactoryProvider`, en
`app/lib/features/emergencias/data/emergency_providers.dart`.

Cada instancia recibe un `EmergencyScope` y debe limitar sus lecturas y escrituras a
esa cuenta y zona. `watch()` entrega únicamente pedidos propios, ofertas propias y
recursos públicos; nunca debe incluir pedidos privados de otros vecinos ni datos
personales de brigadistas. La autorización debe aplicarse también en el servidor.

- `coverageVerified` exige evidencia de cobertura operativa; tener conexión no basta.
- `activeEvent` permite cambiar el inicio al tablero. La activación local del modo
  emergencia no crea un evento en el servidor.
- `saveRequest` conserva el identificador y la clave de idempotencia del borrador.
  Un estado enviado requiere un acuse real; la copia local conserva su mensaje de
  pedido no recibido.
- El historial, los motivos y los próximos pasos proceden del repositorio. La
  confirmación de atención exige la capacidad explícita `canConfirmAttendance`.
- Las ofertas y los reportes de recursos también deben mostrar su estado real de
  entrega, sin prometer recepción ni asignación.
- La verificación y el carácter oficial de una fuente son metadatos confiables.
  El formulario vecinal no puede concederlos.

La fábrica real es nula por defecto. Sin ella, el tablero mantiene las alternativas
oficiales y explica que no existe coordinación disponible. La práctica usa memoria
aislada y conserva los pedidos como locales; no simula un acuse del servidor.

**Integrado en `main` (8 de noviembre de 2026).** `AuthenticatedApp` inyecta
`OperationalEmergencyRepository` para la cuenta y la zona de la sesión: el pedido va por la cola
cifrada de A a la API de B, el estado vuelve por el stream `mi_pedido`, la cobertura sale de
`GET /v1/zonas/{id}/cobertura` y queda en la base de la cuenta, y los recursos vienen del stream
público de la zona. El reporte de un recurso lleva tipo y cantidad, sin texto libre, y las ofertas
quedan en el celular porque B no tiene su ruta. Ver [la integración de la fase](../integracion.md).

## Contactos personales

`emergency_contacts.dart` almacena los contactos en `SecureStore`, separado por cuenta.
`AuthenticatedApp` aporta una única instancia de `EmergencyContactVault` y la misma
instancia de almacenamiento que usa la sesión. El proveedor sin una instancia de
ese almacén no abre almacenamiento real por su cuenta.

La purga revoca las escrituras, vacía los datos en memoria, espera el trabajo pendiente
y elimina la clave cifrada. También elimina la clave si la salida anterior se
interrumpió antes de abrir los contactos. Cerrar la aplicación conserva lo cifrado
en disco; cerrar sesión o cambiar a otra cuenta lo purga. Los contactos no forman
parte del caché público, de los streams compartidos ni de una exportación pública.

La práctica utiliza contactos en memoria. Preparar un SMS no equivale a enviarlo;
en práctica no debe abrirse el compositor nativo con destinatarios reales.

## Datos públicos y antigüedad

Los teléfonos y puntos de encuentro proceden del directorio público de Fase 1, con
fuente y fecha. Sin un punto verificado disponible, la interfaz debe explicar su
ausencia. No se agregan ubicaciones operativas ficticias.

El tablero de la cuenta usa `umbral_segundos` del stream y marca el recurso como posiblemente
desactualizado al alcanzar ese límite. La práctica usa los valores ilustrativos de
`resourceFreshnessPolicyProvider`. La tarjeta muestra la fuente y su fecha de verificación cuando
el recurso está verificado y añade la insignia si la fuente es oficial. Las imágenes se desactivan
al usar el modo emergencia para reducir el consumo de datos.

## Estado de validación

La verificación de frescura se ejecutó con `tool/verify.sh` desde `app/`. Pasaron el análisis, el
formato y 263 pruebas. Se omitió la prueba de PowerSync en vivo, que requiere `LIVE_POWERSYNC`.

- [Política de frescura](../../../app/test/features/emergencias/resource_freshness_policy_test.dart).
  Comprueba los límites de los seis tipos y la precedencia del umbral del servidor.
- [Tarjeta de recursos](../../../app/test/features/emergencias/critical_resource_card_test.dart).
  Comprueba la antigüedad con reloj controlado, la marca, la fecha de la fuente verificada y la insignia.
- [Repositorio operativo](../../../app/test/features/emergencias/operational_emergency_repository_test.dart).
  Siembra una fila del stream y comprueba que el tablero recibe el umbral y la fecha de verificación.

Quedan pendientes el modo avión para estos recursos, la validación de accesibilidad y el simulacro.
