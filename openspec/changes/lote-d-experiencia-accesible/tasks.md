# Tasks

## 1. Parte 1 · Sistema de diseño accesible

- [ ] 1.1 Ampliar `AccessibleTheme` (contrastes verificados por prueba, 48 dp, tipografía legible) y verificar con una prueba que calcula el contraste de cada par
- [ ] 1.2 Componentes base accesibles (botón grande, tarjeta de publicación, aviso destacado) con etiquetas semánticas; verificar con pruebas de widgets y `meetsGuideline`
- [ ] 1.3 Golden tests del muro con escala de texto 1,0 y 2,0; verificar que no hay desbordes
- [ ] 1.4 Modo sencillo (proveedor + menú); verificar con una prueba de widgets
- [ ] 1.5 Compilar y depurar (CI en verde)

## 2. Parte 2 · Publicar en 3 toques

- [ ] 2.1 Pantalla de tipo y formulario mínimo prellenado en `features/publicar/`, conectados a `PublishPost`; verificar con una prueba que cuenta exactamente 3 toques
- [ ] 2.2 Validación en el celular con mensajes junto al campo; verificar con pruebas
- [ ] 2.3 Guardado inmediato y regreso al muro con "Guardado en tu celular"; verificar con el doble en memoria en modo sin conexión
- [ ] 2.4 Dictado por voz opcional (`speech_to_text`) detrás de un botón; verificar en Android real
- [ ] 2.5 Compilar y depurar (CI en verde)

## 3. Parte 3 · Estados visibles y acciones por revisar

- [ ] 3.1 Aviso destacado para lo no enviado y contador de pendientes; verificar con pruebas de widgets
- [ ] 3.2 "Actualizado hace X" y aviso sin conexión con plurales en `app_es.arb`; verificar con pruebas
- [ ] 3.3 Bandeja "Acciones por revisar" con motivo y alternativa por `codigo`; verificar simulando 409 `favor_no_disponible` con `recordResponse`
- [ ] 3.4 Compilar y depurar (CI en verde)

## 4. Parte 4 · Tutorial y modo práctica

- [ ] 4.1 Tutorial con `showcaseview` sobre el muro y el flujo de publicar, repetible desde el menú; verificar con una prueba de widgets
- [ ] 4.2 Modo práctica que nunca encola envíos; verificar con una prueba que el repositorio real no recibe nada
- [ ] 4.3 Paso sobre la falta de señal y los números 116, 105 y 106; verificar el texto con el equipo
- [ ] 4.4 Compilar y depurar (CI en verde)

## Workflow follow-up

- Archivar este change cuando el Lote A apruebe el último PR del lote.
