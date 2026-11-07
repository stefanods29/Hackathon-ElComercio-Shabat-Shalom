# Tasks

## 1. Parte 1 · Sistema de diseño accesible

- [x] 1.1 Ampliar `AccessibleTheme` (contrastes verificados por prueba, 48 dp, tipografía legible) y verificar con una prueba que calcula el contraste de cada par
- [x] 1.2 Componentes base accesibles (botón grande, tarjeta de publicación, aviso destacado) con etiquetas semánticas; verificar con pruebas de widgets y `meetsGuideline`
- [x] 1.3 Golden tests del muro con escala de texto 1,0 y 2,0; verificar que no hay desbordes
- [x] 1.4 Modo sencillo (proveedor + menú); verificar con una prueba de widgets
- [x] 1.5 Compilar y depurar (CI en verde)

## 2. Parte 2 · Publicar en 3 toques

- [x] 2.1 Pantalla de tipo y formulario mínimo prellenado en `features/publicar/`, conectados a `PublishPost`; verificar con una prueba que cuenta exactamente 3 toques
- [x] 2.2 Validación en el celular con mensajes junto al campo; verificar con pruebas
- [x] 2.3 Guardado inmediato y regreso al muro con "Guardado en tu celular"; verificar con el doble en memoria en modo sin conexión
- [x] 2.4 Dictado por voz opcional (`speech_to_text`) detrás de un botón; verificar en Android real
- [x] 2.5 Compilar y depurar (CI en verde)

## 3. Parte 3 · Estados visibles y acciones por revisar

- [x] 3.1 Aviso destacado para lo no enviado y contador de pendientes; verificar con pruebas de widgets
- [x] 3.2 "Actualizado hace X" y aviso sin conexión con plurales en `app_es.arb`; verificar con pruebas
- [x] 3.3 Bandeja "Acciones por revisar" con motivo y alternativa por `codigo`; verificar simulando 409 `favor_no_disponible` con `recordResponse`
- [x] 3.4 Compilar y depurar (CI en verde)

## 4. Parte 4 · Tutorial y modo práctica

- [x] 4.1 Tutorial con `showcaseview` sobre el muro y el flujo de publicar, repetible desde el menú; verificar con una prueba de widgets
- [x] 4.2 Modo práctica que nunca encola envíos; verificar con una prueba que el repositorio real no recibe nada
- [x] 4.3 Paso sobre la falta de señal y los números 116, 105 y 106; verificar el texto con el equipo
- [x] 4.4 Compilar y depurar (CI en verde)

## 5. Parte 5 · Inicio de sesión, zona y cuenta

- [x] 5.1 Puerto `AuthRepository` y estado de sesión (`SignedOut`, `NeedsZone`, `SignedIn`) en `features/cuenta/domain/`, con un doble en memoria que arranca con la sesión de demostración; verificar con pruebas unitarias
- [x] 5.2 Pantallas de teléfono y código (teclado numérico, autocompletado del código, reenvío con cuenta regresiva, errores `codigo_invalido` y `demasiados_intentos` en lenguaje simple); verificar con pruebas de widgets
- [x] 5.3 Pantalla "Elige tu zona" antes de mostrar el muro cuando el vecino no tiene zona; verificar con una prueba de widgets
- [x] 5.4 Pantalla "Mi cuenta" (`/cuenta`): cerrar sesión con aviso de que se borran los datos del celular, "Perdí mi teléfono" (cerrar todas las sesiones), modo sencillo y ver tutorial; verificar con pruebas de widgets
- [x] 5.5 Redirecciones del router según el estado de la sesión (`/ingresar`, `/elegir-zona`); verificar con una prueba que el muro no se ve sin sesión
- [x] 5.6 Compilar y depurar (CI en verde)

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
