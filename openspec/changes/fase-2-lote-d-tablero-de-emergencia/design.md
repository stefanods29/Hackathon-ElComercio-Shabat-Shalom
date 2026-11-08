## Contexto

Las pantallas se usan con miedo, prisa o poca batería: textos cortos, botones grandes y nada que
dependa de la red para mostrarse. La rama del lote se escribió con dobles; la integración de la
Fase 2 conectó el puerto real.

## Decisiones

- **Un puerto por cuenta y zona.** `EmergencyRepository` recibe un `EmergencyScope`; la práctica
  usa memoria aislada y nunca simula un acuse del servidor. Sin integración, la cuenta real ve
  `UnavailableEmergencyRepository` y las alternativas oficiales.
- **Cuenta real.** `OperationalEmergencyRepository` guarda el pedido en la cola cifrada de A con su
  id y su clave; el estado sale del stream `mi_pedido`. La cobertura y el evento vienen de
  `GET /v1/zonas/{id}/cobertura` (B) y quedan en la base de la cuenta: sin señal se puede escribir un
  pedido mientras la última confirmación tenga menos de 12 horas.
- **Sin texto libre en recursos.** B no acepta descripciones del reportante: el reporte real lleva
  tipo, cantidad y el punto aproximado de la zona.
- **Ofertas en el celular.** B no tiene ruta para "Puedo ayudar": la oferta queda guardada en el
  celular y lo dice; no se convierte en habilitación ni en acceso a pedidos.
- **Ubicación aproximada sugerida.** El formulario usa el punto de referencia de la zona y la
  referencia escrita por el vecino, que viaja solo en el detalle privado del pedido.
- **Imágenes.** En modo emergencia, manual o por un evento activo, las imágenes quedan apagadas
  (Lote A, 4.3); fuera de él el vecino puede apagarlas.

## Riesgos

- Todos los pedidos de la zona caen en la celda de su punto de referencia hasta que el vecino pueda
  elegir el punto en el mapa offline.
- Las ofertas se pierden al cerrar la app hasta que B tenga su ruta.
