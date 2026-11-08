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
y muestran el diseño, no la tipografía. Se generaron en macOS y se comparan solo allí, con hasta
un 1 % de diferencia: en la CI de Linux el suavizado de esa fuente cambió más (6 de 6 imágenes
fallaron en el primer intento), así que la CI corre las 27 comprobaciones restantes y salta solo la
comparación de imágenes. Para que la CI también las compare hacen falta referencias generadas en
Linux.

## Lo que no cubre

- Recorrer las pantallas con TalkBack y VoiceOver en un teléfono (tarea D 4.5).
- El alto contraste del sistema operativo: las pruebas comprueban el contraste de los temas de la
  app, no la opción del teléfono.
- La prueba con vecinos del simulacro (D 4.3).

## Teléfonos reales

Preparación del 8 de noviembre de 2026, America/Lima, en
`f2-lote-a/parte-3-y-d-4-telefonos`, desde `origin/main` en `4fb7761`.
Responsable del recorrido y de las observaciones: `JDiazD33`.

**Alcance acordado: Android/TalkBack por ahora. iPhone/VoiceOver no se ejecutó por no disponer de
una Mac con Xcode ni de las herramientas de firma de iOS.** D 4.5 sigue abierta: los resultados
automáticos de arriba no reemplazan ninguno de los recorridos físicos.

La [guía Android](telefonos-android.md#3-d-45-talkback-texto-grande-y-contraste) describe configuración,
gestos, resultados esperados y límites de práctica. Los comandos ejecutados y sus resultados se
registran en el [reporte de la entrega](reporte-telefonos-android.md).

| Registro | Android | iPhone |
|---|---|---|
| Modelo y versión del sistema | POCO X6 Pro informado por el usuario; ADB confirma Xiaomi `2311DRK48G`, Android 16, API 36 | No ejecutado: faltan Mac, Xcode y firma |
| Versión de TalkBack/VoiceOver | `17.1.0.1003738110`, consultada en el dispositivo | No probado |
| Teclado y dictado del sistema | Pendiente | No probado |
| Tamaño de fuente y contraste del sistema | Consulta inicial: `font_scale=1.1` (110 %); `high_text_contrast_enabled` sin valor definido. No se atribuye al teléfono el 200 % de los widgets | No configurado |
| Modo sencillo, tema y sesión usados | Práctica confirmada por el usuario; modo sencillo y tema de la ejecución pendientes | No ejecutado |
| Fecha y commit instalado | 8 de noviembre de 2026; base `4fb7761` más entrada de práctica de esta rama. APK de práctica instalado y actividad abierta por ADB; integridad en el reporte | No instalado |
| Observación física recibida | El usuario confirma la franja «Modo práctica», el acceso con «Estoy en emergencia» y la identificación de «Volver al inicio normal»; pendiente del recorrido con lector | Ninguna |

La confirmación de arranque y navegación corresponde a la variante de práctica del commit
`5f4ec140097e2cc4093c6eaea3d83578747cbba7`, el 8 de noviembre de 2026. No se confirmó que TalkBack
estuviera activo ni se comunicaron anuncios del lector; por ello los pasos D-01 a D-11 conservan
su estado pendiente. Se mantuvo la navegación existente al identificarse el control de salida.

| Paso | Esperado | Observado en Android | Resultado |
|---|---|---|---|
| D-01 · Título y orden | El recorrido comienza por el título del tablero | No ejecutado | Pendiente |
| D-02 · Acciones | Los cuatro botones tienen nombre y función comprensibles | No ejecutado | Pendiente |
| D-03 · Alternativas | Se lee el recordatorio de riesgo para la vida y los números oficiales | No ejecutado | Pendiente |
| D-04 · Tres activaciones | Tablero → necesidad → formulario → guardar, con cada paso anunciado | No ejecutado | Pendiente |
| D-05 · Dictado del teclado | Se puede completar, corregir y regresar al formulario usando TalkBack | No ejecutado | Pendiente |
| D-06 · Pedido local | Se anuncia que el pedido todavía no fue enviado y nadie lo recibió | No ejecutado | Pendiente |
| D-07 · Cambio de estado | El cambio sincronizado se anuncia sin buscarlo | No ejecutado; requiere la API local y una sesión ficticia fuera de práctica | Pendiente |
| D-08 · Recursos | Antigüedad y marca de posiblemente desactualizado se entienden al oírlas | No ejecutado | Pendiente |
| D-09 · Contactos | Se puede agregar y borrar un contacto ficticio solo con el lector | No ejecutado | Pendiente |
| D-10 · Modo sencillo | Las mismas pantallas y controles siguen siendo usables | No ejecutado | Pendiente |
| D-11 · Sistema al 200 % y contraste | Texto, foco y acciones siguen siendo visibles y alcanzables | No ejecutado | Pendiente |

En práctica el botón final dice «Guardar en práctica» y el pedido no pasa a enviado. Su botón
de dictado integrado evita servicios externos; D-05 usa el dictado del teclado. Para evaluar el
dictado propio de la app y el anuncio de una actualización real, se requiere el entorno local
con datos ficticios descrito en la guía. No se alteró el aislamiento para aparentar esos resultados.

No se recibieron todavía fallos observados en el teléfono que justifiquen cambiar etiquetas u
orden de la app. No se modificó `emergency_accessibility_test.dart` ni se añadieron pruebas que
presenten una simulación como validación física. Registrar futuras repeticiones con su nuevo commit.
