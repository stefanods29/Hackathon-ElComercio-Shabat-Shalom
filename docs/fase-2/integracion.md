# Integración de la Fase 2

Los cuatro lotes se unieron en `main` el 8 de noviembre de 2026, en la rama `f2-integracion`:

| Rama | Qué trajo |
|---|---|
| `f2-lote-b/modulo-emergencias` | Módulo Emergencias: eventos, pedidos, operación, recursos, privacidad y su contrato |
| `f2-lote-c/consola-web-y-avisos-urgentes` | Consola web, curaduría, avisos urgentes y, dentro de ella, la rama del Lote D |
| `f2-lote-a/parte-4-tablero-offline` | Las partes 1 a 4 del Lote A, encadenadas |

B, C y D se habían escrito sin compilar ni probar. La integración los dejó compilando, con sus
errores corregidos y con pruebas nuevas donde no había ninguna.

## Cómo encajan ahora

| Punto de contacto | Lo que quedó |
|---|---|
| Pedido de la app a la API | El tablero de D usa `OperationalEmergencyRepository`: el pedido va por la cola cifrada de A a `POST /v1/pedidos-ayuda` (B) con su id y su clave; el estado vuelve por el stream `mi_pedido` |
| Cobertura y evento | `GET /v1/zonas/{id}/cobertura` (B). La última confirmación queda en la base de la cuenta y vale 12 horas sin señal |
| Historial del autor | B publica `emergencias.historial_para_autor`: sin el usuario ni el motivo operativo; solo las derivaciones y los cierres conservan un motivo para el vecino |
| Caso asignado en el celular | `POST /v1/pedidos-ayuda/{id}/accesos-sincronizacion` (B) concede un permiso auditado, ligado a la asignación, la sesión y el alcance. Se revoca con la asignación |
| Ubicación exacta | `emergencias.ubicaciones_en_camino` solo tiene los casos en camino; `detalles_pedidos` sigue fuera de la publicación de PowerSync |
| Tablero offline | Los streams de agregados y recursos de A leen las tablas públicas de B; los recursos traen la fecha de su verificación (`verificado_en`) |
| Consola | Los adaptadores HTTP de casos, celdas y turnos usan las rutas de B. Quien no tiene un caso lo toma antes de cambiarlo |
| Avisos | El aviso público de zona es solo de Notificaciones (C); B ya no envía uno propio. Los avisos urgentes de C se activan por defecto |
| Push en la app | `modo_emergencia_activado` abre el tablero; `aviso_urgente` abre el caso asignado; `pedido_actualizado` abre el pedido propio |
| Curaduría | Admite el rol `curador` que agregó B |

## Decisiones entre lotes

Cuando dos lotes no coincidían, se siguió el plan aprobado de cada guía:

- **Ubicación exacta por stream.** La guía de A pide "un stream aparte que depende del estado"; B
  había dejado la ubicación solo en la API. Se publicó una copia mínima de los casos en camino que
  mantienen disparadores de la base, para no publicar los detalles privados.
- **Imágenes en emergencia.** La especificación de A obliga a desactivarlas en modo emergencia; D
  permitía encenderlas. Quedan apagadas en emergencia, manual o por un evento activo.
- **Totales por celda.** C esperaba totales; B no los publica porque un total menos las necesidades
  visibles revelaría un «menos de 3». La consola no muestra totales y, con todas las necesidades,
  colorea por la necesidad más cargada, nunca por una suma.
- **Asignar no es "en camino".** La consola suponía que asignar una brigadista pasaba el caso a en
  camino; en B lo confirma la brigadista desde el celular.
- **Recursos sin texto libre.** B no acepta descripciones del reportante: el formulario real de D
  pide tipo y cantidad.
- **Ofertas.** B no tiene ruta para "Puedo ayudar": la oferta queda en el celular y lo dice.

## Verificación local

Todo en la versión integrada, en una Mac con Node 26, Flutter 3.47 y PostgreSQL con PostGIS:

| Comprobación | Resultado |
|---|---|
| `npm run verify` (backend) | Verde: tipos, lint, formato, límites de módulos, Sync Streams, 246 pruebas y build |
| `npm run test:integration` | 199 de 199, incluida la nueva prueba del hito H2 por la API |
| `tool/verify.sh` (app) | Verde: análisis, 251 pruebas (1 omitida) y formato |
| Consola | `flutter analyze` sin avisos, 7 pruebas nuevas, formato y `flutter build web --release` |
| `npm test` en `infra/cdn` | 10 de 10 |
| `npx @redocly/cli lint contracts/openapi.yaml` | Válido; 6 avisos, 3 ya estaban en `main` y 3 vienen del esquema del directorio |
| `openspec validate --all --strict` | Válido, con el change nuevo del Lote D |

La prueba `backend/test/integration/emergencies.int-spec.ts` recorre el hito H2 por la API:
habilitaciones, turnos, evento, cobertura, pedido idempotente, cola sin datos privados, asignación,
permiso del stream, en camino, ubicación exacta solo entonces, atención confirmada por el vecino,
revocación de los permisos y auditoría sin contenido.

## Lo que sigue pendiente

Actualizado al unir las entregas del 8 de noviembre de 2026 (pruebas de B y D, consola, PowerSync
en vivo, referencias en Linux, teléfonos, revisión de migraciones, nube y seguridad).

Ya hecho:

- ~~CI de la versión integrada~~, con Android e iOS ([evidencia](evidencias/ci-integracion.md)).
- ~~Consola contra la API real~~ ([evidencia](evidencias/consola-contra-api.md)) y sus pruebas de
  pantallas ([evidencia](evidencias/pantallas-c.md)).
- ~~PowerSync en vivo con dos cuentas~~ ([evidencia](evidencias/powersync-en-vivo.md)).
- ~~Pruebas de D~~: pantallas ([evidencia](evidencias/pantallas-d.md)), frescura y accesibilidad
  automática con referencias en macOS y Linux ([evidencia](evidencias/accesibilidad-modo-emergencia.md)).
- ~~Escalamiento, concurrencia y supresión de B~~ con reloj de prueba y PostgreSQL.

Falta:

- **Modo avión en las pantallas de D (A 1.5)** en el simulador o un teléfono.
- **Teléfonos reales:** capturas bloqueadas en Android (A 3.2), TalkBack y VoiceOver (D 4.5) y la
  prueba de campo (A 5.2). El iPhone ya ocultó el caso en el selector de apps
  ([registro](evidencias/modo-operativo.md#teléfonos-reales)).
- **Seguridad:** el recorrido manual de OWASP MASVS en teléfonos y actualizar las dependencias con
  avisos moderados ([evidencia](evidencias/penetracion.md)).
- **Decisiones del equipo:** revisión conjunta de migraciones (B 5.3), ruta de ofertas (D 3.3),
  proveedor de SMS (C 4.5), staging para la nube (C 3.5), tiempos con los aliados y evaluación de
  impacto.
- **Simulacro con los aliados y prueba con vecinos** (A 6 y D 4.3), con el libreto ya preparado
  ([libreto](evidencias/simulacro.md)).
- **Puntos a mejorar:** elegir el punto del pedido en el mapa offline y que la consola permita a una
  brigadista ver sus casos.
