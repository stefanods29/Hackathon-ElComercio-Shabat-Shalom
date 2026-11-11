# Tasks

Rama: `f2-diseno/rediseno-emergencia`. Las tareas de implementación se marcan con el código y las
pruebas de la app en verde en esta rama; las de verificación en teléfonos quedan abiertas hasta
tener su evidencia.

Verificación del 10 de noviembre de 2026 en macOS: `tool/verify.sh` desde `app/` terminó en
"App verificada" (análisis sin avisos, 339 pruebas pasan y 1 omitida, formato sin cambios).
Capturas revisadas con fuente real a 414 × 896 y 360 × 800, en tema claro y oscuro y con el texto
al 200 %.

## 1. Parte 1 · Nombres, textos y componentes

- [x] 1.1 Renombrar: "Números y lugares" (`emergencyTitle`), "Emergencia" (`emergencyDashboard`), "Recursos cerca" y "Mis contactos"; "Estoy en emergencia" queda solo en el inicio. Verificación: `flutter analyze` sin avisos y la prueba del directorio sin botones para activar el modo.
- [x] 1.2 Acortar los avisos de cobertura, conexión, ubicación y estados del pedido, sin tocar los textos que exigen las especificaciones vigentes. Verificación: pruebas de `help_request_status_card_test.dart` y `public_emergency_board_test.dart` sin cambios.
- [x] 1.3 Componentes en `emergency_ui.dart` (franja de llamadas, aviso de una línea, etiquetas, botón principal, accesos, línea de tiempo) y chip "Práctica" con las simulaciones en `EmergencyLayout`. Verificación: `emergency_accessibility_test.dart` (contraste claro y oscuro, botones de 48 dp con nombre).
- [x] 1.4 Reemplazar los errores técnicos del muro y de publicar por mensajes del archivo de textos. Verificación: `flutter analyze` y revisión del diff.
- [x] 1.5 Compilar y depurar lo tocado: `flutter analyze` y `flutter test` de la app.

## 2. Parte 2 · Tablero, pedido y formulario

- [x] 2.1 Tablero en una pantalla: llamadas arriba, línea de estado, pedido propio, "Necesito ayuda" único y cuadrícula de accesos; ahorro de datos en una fila. Verificación: captura a 414 × 896 y prueba de orden de lectura (título, llamadas, ayuda).
- [x] 2.2 Cuadrícula de seis necesidades y formulario con dos preguntas, dictado como ícono y referencia opcional. Verificación: prueba de tres toques y de reintento con la misma clave.
- [x] 2.3 "Mi pedido" con banda de estado y línea de tiempo; sin "Enviado" mientras el pedido está en el celular. Verificación: pruebas de cada estado, lista permitida de textos del pedido en camino y modo avión simulado.
- [x] 2.4 Activar desde el inicio avisa que no notifica a nadie y el ahorro de datos no deja encender imágenes en emergencia. Verificación: prueba de widgets desde el muro.
- [x] 2.5 Compilar y depurar lo tocado: `flutter analyze` y `flutter test` de la app.

## 3. Parte 3 · Recursos cerca y Números y lugares

- [x] 3.1 "Recursos cerca" con filtros, orden por reporte, etiquetas de antigüedad y verificación, pestaña de pedidos por sector y reporte en pantalla propia. Verificación: `critical_resource_card_test.dart` (umbral y lectura completa del aviso) y captura.
- [x] 3.2 "Números y lugares" con un número por fila, fuente en una línea con enlace y lugares con mapa; sin botones para activar el modo. Verificación: prueba del directorio y captura.
- [x] 3.3 Regenerar las seis referencias visuales de macOS (`flutter test --update-goldens test/features/emergencias/emergency_accessibility_test.dart`).
- [x] 3.4 Compilar y depurar lo tocado: `flutter analyze` y `flutter test` de la app.

## 4. Parte 4 · Ajustes tras probar en el iPhone

- [x] 4.1 Inicio sigue mostrando el muro en modo emergencia, con un aviso que lleva a Emergencia; la app cambia sola a la pestaña Emergencia al activarse el modo o un evento. Verificación: `main_shell_test.dart` y la prueba del muro con evento activo.
- [x] 4.2 Botones de llamada sin cortes: el nombre se achica en vez de partirse y los botones se apilan cuando no caben. Verificación: prueba de los botones a 342 y 288 dp y con letra al 130 %, y captura con letra al 120 %.
- [x] 4.3 "Reportar un recurso" con tipos en cuadrícula, contador de cantidad y dictado del detalle (también en práctica); textos del permiso de micrófono de iOS. Verificación: `report_resource_page_test.dart` y la pantalla `reportar` en `emergency_accessibility_test.dart`.
- [x] 4.4 Compilar y depurar lo tocado: `tool/verify.sh` e instalación de la variante demo en el iPhone XR.

## 5. Parte 5 · Verificación fuera del laboratorio

- [ ] 5.1 Regenerar las referencias visuales de Linux en el contenedor de `infra/flutter/Dockerfile`.
- [ ] 5.2 Recorrer el modo emergencia en Android y iOS reales con texto grande, tema oscuro, TalkBack y VoiceOver; registrar el resultado en `docs/fase-2/evidencias/accesibilidad-modo-emergencia.md`.
- [ ] 5.3 Confirmar la CI en verde de la rama antes de integrarla.
