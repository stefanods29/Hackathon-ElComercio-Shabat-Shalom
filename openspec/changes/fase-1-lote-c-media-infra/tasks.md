Por indicación del usuario se suspendió la ejecución de compilaciones y pruebas. Los resultados
anteriores y los cambios finales sin ejecutar constan en `docs/fase-1/evidencias/lote-c.md`.
Los checks de implementación no equivalen a aceptación del equipo ni verificación final.

## 1. Parte 1 · Backend Media
- [x] 1.1 Definir el contrato de archivos y validarlo con Redocly.
- [x] 1.2 Implementar registro, firma, confirmación y baja con pruebas de autorización/idempotencia.
- [x] 1.3 Implementar worker recuperable, saneamiento y miniaturas; probar EXIF, huellas y fallos.
- [x] 1.4 Verificar integración con PostgreSQL y compilar backend localmente.
- [ ] 1.5 Compilar y depurar la revisión final en CI cuando se reanude la verificación.

## 2. Parte 2 · Fotos en la app
- [x] 2.1 Implementar saneamiento, borradores cifrados y cola; agregar pruebas de persistencia y cuentas.
- [x] 2.2 Integrar transferencias nativas, miniaturas, selección/estado y pruebas con dobles/widgets.
- [x] 2.3 Proteger cierre/cambio de cuenta y documentar el enlace con A/B/D.
- [ ] 2.4 Compilar y depurar Android/iOS y CI; ejecutar regresiones finales, suspensión y recuperación en dispositivos.

## 3. Parte 3 · Compartir
- [x] 3.1 Implementar selector del teléfono con contenido público y enlaces válidos; probar privacidad.
- [x] 3.2 Documentar dominio, destino público y asociaciones pendientes.
- [ ] 3.3 Compilar y depurar la app en CI y comprobar compartir/cancelar en Android/iPhone.

## 4. Parte 4 · Monitoreo
- [x] 4.1 Implementar OpenTelemetry y Sentry opcionales con listas permitidas de información.
- [x] 4.2 Agregar pruebas de privacidad y documentar la captura Dart sin plugin nativo.
- [ ] 4.3 Compilar y depurar la revisión final en CI y comprobar recepción real configurada.

## 5. Parte 5 · Entornos
- [x] 5.1 Preparar propuesta OpenTofu dev/staging/prod y validarla sin desplegar.
- [x] 5.2 Agregar almacenamiento/monitoreo locales, documentación y workflow; validar el recolector oficial.
- [ ] 5.3 Compilar y depurar imágenes en CI; revisar presupuesto, configuración privada y aceptación con el equipo.
