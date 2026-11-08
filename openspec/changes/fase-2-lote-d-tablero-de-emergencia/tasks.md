# Tasks

Las tareas de implementación se marcan con el código integrado en `main` (análisis y pruebas de la
app en verde). Las de verificación quedan abiertas hasta tener su evidencia.

## 1. Parte 1 · Inicio en modo emergencia

- [x] 1.1 Tablero de inicio con evento activo o modo emergencia, alternativas oficiales y ahorro de datos.
- [x] 1.2 Integrar el puerto real con la cobertura y el evento del Lote B.
- [ ] 1.3 Verificar con pruebas de widgets: zona sin cobertura, evento activo y modo manual.

## 2. Parte 2 · "Necesito ayuda" y el estado de mi pedido

- [x] 2.1 Pedido en tres toques, dictado opcional y estado local sin acuse.
- [x] 2.2 Conectar la cola y el stream del autor del Lote A (cuenta real).
- [ ] 2.3 Verificar con pruebas de widgets de cada estado y mensaje, el flujo de tres toques contado y una prueba en modo avión.

## 3. Parte 3 · "Puedo ayudar" y recursos

- [x] 3.1 Ofertas guardadas en el celular y lista de recursos con antigüedad, verificación y fuente.
- [x] 3.2 Reporte real con tipo, cantidad y punto aproximado, sin texto libre.
- [ ] 3.3 Definir con el Lote B la ruta de las ofertas; verificar que la oferta llega a coordinación.
- [ ] 3.4 Verificar con reloj de prueba la marca de posiblemente desactualizado por tipo.

## 4. Parte 4 · Contactos de emergencia y accesibilidad

- [x] 4.1 Contactos cifrados por cuenta, purga al cerrar sesión y SMS preparado sin enviar.
- [x] 4.2 Revisar la accesibilidad del modo emergencia de forma automática: texto grande, modo sencillo, contraste, tamaño y nombre de los botones, orden del lector de pantalla y golden tests al 200 %. Evidencia: [accesibilidad automática](../../../docs/fase-2/evidencias/accesibilidad-modo-emergencia.md).
- [ ] 4.3 Registrar la prueba con vecinos en `docs/fase-2/evidencias/simulacro.md`.
- [x] 4.4 Verificar CI en verde con la versión integrada. Evidencia: [CI de la versión integrada](../../../docs/fase-2/evidencias/ci-integracion.md).
- [ ] 4.5 Recorrer el modo emergencia con TalkBack y VoiceOver en teléfonos y con el alto contraste del sistema; registrar el resultado en `docs/fase-2/evidencias/accesibilidad-modo-emergencia.md`.

  Preparación: [TalkBack](../../../docs/fase-2/evidencias/telefonos-android.md#3-d-45-talkback-texto-grande-y-contraste), [VoiceOver](../../../docs/fase-2/evidencias/telefonos-ios.md#d-45--voiceover-texto-grande-y-contraste) y [registro de teléfonos reales](../../../docs/fase-2/evidencias/accesibilidad-modo-emergencia.md#teléfonos-reales). Faltan las observaciones de ambos recorridos con el lector, el texto grande y el contraste del sistema.
