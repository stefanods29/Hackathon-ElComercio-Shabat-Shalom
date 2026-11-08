# Accesibilidad automática del modo emergencia

Fase 2, Lote D, tarea 4.2 (parte automática). Verificado el 8 de noviembre de 2026 con Flutter 3.47
sobre `main`.

```bash
cd app
flutter test test/features/emergencias/emergency_accessibility_test.dart
```

## Qué cubre

Seis pantallas: tablero, tipo de necesidad, formulario, pedido propio, recursos y contactos. Las
pruebas usan una cuenta de práctica con un pedido en camino y recursos ficticios.

| Comprobación | Cómo | Resultado |
|---|---|---|
| Texto grande | Texto al 200 %, sin desbordes ni excepciones | Pasa en las 6 |
| Botones grandes y con nombre | `androidTapTargetGuideline` (48 dp), `iOSTapTargetGuideline` (44 pt) y `labeledTapTargetGuideline` al 200 % | Pasa en las 6 |
| Contraste del texto | `textContrastGuideline` (WCAG) en tema claro y oscuro | Pasa en las 6 |
| Modo sencillo | El texto crece sin desbordes y la preferencia queda guardada | Pasa en las 6 |
| Orden del lector de pantalla | Recorrido simulado: el tablero empieza por su título y "Necesito ayuda" va después; en el pedido propio el estado se lee antes que las alternativas oficiales | Pasa |
| Referencias visuales (goldens) | Una imagen por pantalla al 200 % en `app/test/features/emergencias/goldens/` | Pasa |

Resultado: 33 de 33, y `tool/verify.sh` en verde con 284 pruebas.

Las imágenes de referencia usan la fuente de prueba de Flutter, que dibuja las letras como bloques,
para que sean iguales en macOS y en la CI de Linux. Muestran el diseño, no la tipografía. Se acepta
hasta un 1 % de diferencia de píxeles por el suavizado de cada sistema.

## Lo que no cubre

- Recorrer las pantallas con TalkBack y VoiceOver en un teléfono (tarea D 4.5).
- El alto contraste del sistema operativo: las pruebas comprueban el contraste de los temas de la
  app, no la opción del teléfono.
- La prueba con vecinos del simulacro (D 4.3).
