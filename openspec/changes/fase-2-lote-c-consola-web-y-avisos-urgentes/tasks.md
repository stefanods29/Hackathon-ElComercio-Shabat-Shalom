# Tasks

Entrega de código sin pruebas, análisis, compilación ni CI, por indicación del responsable. Las
tareas de implementación están marcadas; las de verificación quedan abiertas.

## 1. Parte 1 · Base de la consola web

- [x] 1.1 ADR 0014 (Flutter web frente a React: mantenimiento, accesibilidad y tamaño); verificar con su aprobación en la revisión del lote
- [x] 1.2 Proyecto `consola/` con tema accesible, textos en ARB, cliente HTTP con Problem Details y sesión solo en memoria; verificar con `flutter analyze` y `flutter build web`
- [x] 1.3 Ingreso con OTP (API o Firebase), solo para roles operativos, y cierre por inactividad con aviso; verificar con pruebas de widgets (sin rol operativo, inactividad)
- [x] 1.4 CORS por `CONSOLE_ORIGINS` y `Cache-Control: no-store` en las rutas operativas de la API; verificar con una prueba de integración de los encabezados
- [x] 1.5 Módulo `infra/cloud/modules/console-site` (Cloudflare Pages, dominio y DNS) y `consola/tool/write_headers.sh` (CSP e `index.html` sin caché); verificar con `tofu validate`
- [ ] 1.6 Flujo `.github/workflows/consola.yml` según el esquema de `integracion.md`; verificar con la CI en verde
- [ ] 1.7 Verificar: `flutter analyze`, pruebas de widgets, `flutter build web`, `tofu validate` y CI en verde

## 2. Parte 2 · Cola de casos y asignación

- [x] 2.1 Dominio de casos: prioridades, tiempos de primera revisión, marcas "por escalar" y "fuera de tiempo", transiciones de la sección 7.2 y regla de ubicación exacta; verificar con pruebas unitarias de la tabla de transiciones y de los tiempos
- [x] 2.2 Puerto `CasesRepository` con fábrica operativa nula y doble de demostración; verificar con pruebas de la cola con el doble
- [x] 2.3 Cola con refresco y detalle minimizado: asignación, cambio de estado con motivo e historial; verificar con pruebas de widgets al 200 % y con teclado
- [x] 2.4 Errores de la API explicados según su `codigo`; verificar con pruebas de cada código conocido
- [ ] 2.5 Conectar el puerto al contrato de Emergencias del Lote B cuando exista; verificar con pruebas de integración contra la API
- [ ] 2.6 Verificar: `flutter analyze`, pruebas y CI en verde

## 3. Parte 3 · Mapa de celdas, turnos y curaduría

- [x] 3.1 Mapa de celdas con MapLibre y tabla equivalente, con umbral de 3; verificar con pruebas de la tabla
- [x] 3.2 Turnos y regla de cobertura; verificar con pruebas unitarias de la regla
- [x] 3.3 Módulo `curaduria`: validación con el esquema de la Fase 1, versiones con concurrencia optimista, publicación del archivo y del índice; verificar con pruebas de integración (422, 409 y 404) y con `npm test` en `infra/cdn` sobre lo publicado
- [x] 3.4 Pantallas de curaduría y de la cola de moderación de la Fase 1; verificar con pruebas de widgets
- [ ] 3.5 Adaptador de almacenamiento en la nube para la publicación, alineado con la Fase 1, Lote C; verificar en staging
- [ ] 3.6 Verificar: `npm run verify`, `npm run test:integration`, `npm run graph`, `flutter analyze` y CI en verde

## 4. Parte 4 · Avisos urgentes con SMS de respaldo

- [x] 4.1 Contrato de `GET /v1/avisos-urgentes`, `POST /v1/avisos-urgentes/{id}/confirmar` y `GET /v1/operacion/avisos-urgentes/resumen`; verificar con `npx @redocly/cli lint contracts/openapi.yaml`
- [x] 4.2 Migración, trabajo `notificaciones.enviar_aviso_urgente`, revisión con el plazo de confirmación y SMS por el adaptador falso con tope diario y mensual; verificar con pruebas (el token falla y se envía el SMS, tope alcanzado, confirmado a tiempo, trabajo repetido)
- [x] 4.3 Aviso público de zona con `emergencias.evento_activado` y plantillas genéricas; verificar con la revisión de cada plantilla en `templates.spec.ts`
- [x] 4.4 Confirmación del aviso urgente al abrirlo en la app y en la consola; verificar con pruebas de `routeFor` y del banner
- [ ] 4.5 Elegir el proveedor real de SMS (13.3.4) y su adaptador; verificar con una prueba manual registrada en `docs/fase-2/evidencias/`
- [ ] 4.6 Verificar: `npm run verify`, `npm run test:integration`, `tool/verify.sh` y CI en verde
